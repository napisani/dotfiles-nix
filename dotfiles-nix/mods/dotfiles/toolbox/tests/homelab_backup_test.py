#!/usr/bin/env python3
"""
Tests for homelab_backup.py

Run with:
    uv run --with pytest pytest mods/dotfiles/toolbox/tests/homelab_backup_test.py -v
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path
from typing import Any

import pytest

SCRIPT = Path(__file__).parent.parent / "homelab_backup.py"

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

DEFAULT_SSH_ENV = {
    "SSH_HOST": "backup.example.com",
    "SSH_USER": "backup",
    "SSH_PORT": "22",
    "REMOTE_REPO_BASE": "/srv/restic/supermicro",
}


@pytest.fixture()
def workspace(tmp_path: Path) -> Path:
    return tmp_path


@pytest.fixture()
def repos_dir(tmp_path: Path) -> Path:
    d = tmp_path / "repos"
    d.mkdir()
    return d


@pytest.fixture()
def stub_bin(tmp_path: Path) -> Path:
    """
    Build a directory of stub commands (restic, curl) that log calls to
    RESTIC_LOG_FILE and track initialised repositories via RESTIC_REPOS_DIR.
    """
    d = tmp_path / "bin"
    d.mkdir()

    restic = d / "restic"
    restic.write_text("""\
#!/usr/bin/env bash
# Stub restic: logs all calls, tracks repo state via RESTIC_REPOS_DIR.

REPO_ARG="${2:-}"
OP="${3:-}"

# Log every invocation to the log file (if set).
if [[ -n "${RESTIC_LOG_FILE:-}" ]]; then
    printf '%s\\n' "$*" >> "${RESTIC_LOG_FILE}"
fi

_repo_key() {
    printf '%s' "$1" | tr -s '/:@.' '_' | tr -dc '[:alnum:]_'
}

case "${OP}" in
    init)
        if [[ -n "${RESTIC_REPOS_DIR:-}" ]]; then
            touch "${RESTIC_REPOS_DIR}/$(_repo_key "${REPO_ARG}")"
        fi
        ;;
    snapshots)
        if [[ -n "${RESTIC_REPOS_DIR:-}" ]]; then
            [[ -f "${RESTIC_REPOS_DIR}/$(_repo_key "${REPO_ARG}")" ]] || exit 1
        else
            exit 1
        fi
        ;;
esac

exit 0
""")
    restic.chmod(0o755)

    curl = d / "curl"
    curl.write_text("#!/usr/bin/env bash\nexit 0\n")
    curl.chmod(0o755)

    return d


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def run_script(
    stub_bin: Path,
    extra_env: dict[str, str],
    args: list[str] | None = None,
    repos_dir: Path | None = None,
    restic_log: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    """Run backup.py via `uv run` with the given environment overrides."""
    env: dict[str, str] = {**os.environ}
    # prepend stubs before real PATH
    env["PATH"] = f"{stub_bin}:{env['PATH']}"
    env["LOG_FILE"] = ""
    env["NTFY_TOPIC"] = ""
    if repos_dir is not None:
        env["RESTIC_REPOS_DIR"] = str(repos_dir)
    if restic_log is not None:
        env["RESTIC_LOG_FILE"] = str(restic_log)
    env.update(extra_env)
    cmd = ["uv", "run", str(SCRIPT)]
    if args:
        cmd.extend(args)
    return subprocess.run(cmd, env=env, capture_output=True, text=True)


def combined(result: subprocess.CompletedProcess[str]) -> str:
    return result.stdout + result.stderr


def read_restic_log(log_path: Path) -> list[str]:
    if not log_path.exists():
        return []
    return log_path.read_text().splitlines()


def mark_repo_initialized(repos_dir: Path, repo_url: str) -> None:
    """Pre-seed the stub's repo state to simulate an already-initialised repo.

    Key generation must mirror the stub's _repo_key function:
        tr -s '/:@.' '_' | tr -dc '[:alnum:]_'
    The -s flag squeezes consecutive matching chars into one replacement.
    """
    import re

    key = re.sub(r"[/:@.]+", "_", repo_url)   # tr -s '/:@.' '_'  (+ squeezes runs)
    key = re.sub(r"[^a-zA-Z0-9_]", "", key)   # tr -dc '[:alnum:]_'
    (repos_dir / key).touch()


# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

def test_help(stub_bin: Path, workspace: Path) -> None:
    result = run_script(stub_bin, {}, args=["--help"])
    assert result.returncode == 0, combined(result)
    assert "Usage:" in combined(result)
    assert "--dry-run" in combined(result)


# ---------------------------------------------------------------------------
# Fail-fast: missing password
# ---------------------------------------------------------------------------

def test_requires_restic_password(
    stub_bin: Path, workspace: Path, repos_dir: Path
) -> None:
    source = workspace / "source"
    source.mkdir()
    env = {
        **DEFAULT_SSH_ENV,
        "BACKUP_PAIRS_JSON": json.dumps([f"{source}:source"]),
    }
    env.pop("HOMELAB_BACKUP_RESTIC_PASSWORD", None)

    result = run_script(stub_bin, env, repos_dir=repos_dir)

    assert result.returncode != 0
    assert "HOMELAB_BACKUP_RESTIC_PASSWORD" in combined(result)


# ---------------------------------------------------------------------------
# Fail-fast: missing SSH config
# ---------------------------------------------------------------------------

def test_requires_ssh_config(
    stub_bin: Path, workspace: Path, repos_dir: Path
) -> None:
    source = workspace / "source"
    source.mkdir()
    env = {
        **DEFAULT_SSH_ENV,
        "SSH_HOST": "",            # blank → should fail
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
        "BACKUP_PAIRS_JSON": json.dumps([f"{source}:source"]),
    }

    result = run_script(stub_bin, env, repos_dir=repos_dir)

    assert result.returncode != 0
    assert "Required configuration 'SSH_HOST' is not set." in combined(result)


# ---------------------------------------------------------------------------
# repo URL: non-standard SSH port
# ---------------------------------------------------------------------------

def test_build_repo_url_includes_non_default_ssh_port(
    stub_bin: Path, workspace: Path, repos_dir: Path, tmp_path: Path
) -> None:
    source = workspace / "source"
    source.mkdir()
    restic_log = tmp_path / "restic.log"

    env = {
        **DEFAULT_SSH_ENV,
        "SSH_PORT": "2222",
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
        "BACKUP_PAIRS_JSON": json.dumps([f"{source}:source"]),
    }

    result = run_script(stub_bin, env, repos_dir=repos_dir, restic_log=restic_log)

    assert result.returncode == 0, combined(result)
    calls = read_restic_log(restic_log)
    expected_url = "sftp://backup@backup.example.com:2222/srv/restic/supermicro/source"
    assert any(expected_url in line for line in calls), (
        f"Expected URL {expected_url!r} in restic calls:\n" + "\n".join(calls)
    )


# ---------------------------------------------------------------------------
# Main restic flow: init → backup → forget
# ---------------------------------------------------------------------------

def test_main_restic_flow(
    stub_bin: Path, workspace: Path, repos_dir: Path, tmp_path: Path
) -> None:
    source = workspace / "source"
    source.mkdir()
    restic_log = tmp_path / "restic.log"
    repo_url = "sftp:backup@backup.example.com:/srv/restic/supermicro/source"

    env = {
        **DEFAULT_SSH_ENV,
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
        "BACKUP_PAIRS_JSON": json.dumps([f"{source}:source"]),
    }

    result = run_script(stub_bin, env, repos_dir=repos_dir, restic_log=restic_log)

    assert result.returncode == 0, combined(result)
    assert restic_log.exists(), "restic log should be created"

    calls = read_restic_log(restic_log)
    assert f"--repo {repo_url} init" in calls
    assert f"--repo {repo_url} backup {source}" in calls
    assert f"--repo {repo_url} forget --keep-last 5 --prune" in calls


# ---------------------------------------------------------------------------
# Best-effort: one failing pair does not stop the others
# ---------------------------------------------------------------------------

def test_best_effort_pair_failure(
    stub_bin: Path, workspace: Path, repos_dir: Path, tmp_path: Path
) -> None:
    good_source = workspace / "good-source"
    good_source.mkdir()
    missing_source = workspace / "missing-source"   # intentionally absent
    restic_log = tmp_path / "restic.log"

    good_url = "sftp:backup@backup.example.com:/srv/restic/supermicro/good-repo"
    missing_url = "sftp:backup@backup.example.com:/srv/restic/supermicro/missing-repo"

    env = {
        **DEFAULT_SSH_ENV,
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
        "BACKUP_PAIRS_JSON": json.dumps([
            f"{missing_source}:missing-repo",
            f"{good_source}:good-repo",
        ]),
    }

    result = run_script(stub_bin, env, repos_dir=repos_dir, restic_log=restic_log)

    assert result.returncode != 0, "should exit non-zero when any pair fails"
    out = combined(result)
    assert f"Source directory '{missing_source}' does not exist." in out
    assert "Backup completed with 1 failed pair(s)." in out

    calls = read_restic_log(restic_log)
    assert f"--repo {good_url} init" in calls
    assert f"--repo {good_url} backup {good_source}" in calls
    assert f"--repo {good_url} forget --keep-last 5 --prune" in calls
    assert not any(missing_url in line for line in calls)


# ---------------------------------------------------------------------------
# Dry run: existing repo → backup and forget receive --dry-run
# ---------------------------------------------------------------------------

def test_dry_run_existing_repo(
    stub_bin: Path, workspace: Path, repos_dir: Path, tmp_path: Path
) -> None:
    source = workspace / "source"
    source.mkdir()
    restic_log = tmp_path / "restic.log"
    repo_url = "sftp:backup@backup.example.com:/srv/restic/supermicro/source"

    # Pre-seed the stub so snapshots returns 0 (repo already exists)
    mark_repo_initialized(repos_dir, repo_url)

    env = {
        **DEFAULT_SSH_ENV,
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
        "BACKUP_PAIRS_JSON": json.dumps([f"{source}:source"]),
    }

    result = run_script(stub_bin, env, args=["--dry-run"], repos_dir=repos_dir, restic_log=restic_log)

    assert result.returncode == 0, combined(result)
    calls = read_restic_log(restic_log)
    assert f"--repo {repo_url} backup {source} --dry-run" in calls
    assert f"--repo {repo_url} forget --keep-last 5 --prune --dry-run" in calls
    assert not any("init" in line for line in calls), "init should not be called for existing repo"


# ---------------------------------------------------------------------------
# Dry run: new repo → logs "would initialize", skips backup and forget
# ---------------------------------------------------------------------------

def test_dry_run_new_repo(
    stub_bin: Path, workspace: Path, repos_dir: Path, tmp_path: Path
) -> None:
    source = workspace / "source"
    source.mkdir()
    restic_log = tmp_path / "restic.log"
    repo_url = "sftp:backup@backup.example.com:/srv/restic/supermicro/source"

    env = {
        **DEFAULT_SSH_ENV,
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
        "BACKUP_PAIRS_JSON": json.dumps([f"{source}:source"]),
    }

    result = run_script(stub_bin, env, args=["--dry-run"], repos_dir=repos_dir, restic_log=restic_log)

    assert result.returncode == 0, combined(result)
    assert f"Dry run: would initialize restic repository at '{repo_url}'." in combined(result)

    # backup and forget must not be called for a repo that does not yet exist.
    # Check by operation, not substring, because the URL itself contains "backup"
    # (sftp:backup@...).
    calls = read_restic_log(restic_log) if restic_log.exists() else []
    assert not any(f"{repo_url} backup" in line for line in calls)
    assert not any(f"{repo_url} forget" in line for line in calls)
