#!/usr/bin/env python3
"""
Tests for homelab_restore.py

Run with:
    uv run --with pytest pytest mods/dotfiles/toolbox/tests/homelab_restore_test.py -v
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).parent.parent / "homelab_restore.py"

# ---------------------------------------------------------------------------
# Shared fixtures (same pattern as homelab_backup_test.py)
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
    d = tmp_path / "bin"
    d.mkdir()

    restic = d / "restic"
    restic.write_text("""\
#!/usr/bin/env bash
# Stub restic: logs all calls, tracks repo state via RESTIC_REPOS_DIR.

REPO_ARG="${2:-}"
OP="${3:-}"

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
    env: dict[str, str] = {**os.environ}
    env["PATH"] = f"{stub_bin}:{env['PATH']}"
    env["LOG_FILE"] = ""
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
    import re
    key = re.sub(r"[/:@.]+", "_", repo_url)
    key = re.sub(r"[^a-zA-Z0-9_]", "", key)
    (repos_dir / key).touch()


# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

def test_help(stub_bin: Path) -> None:
    result = run_script(stub_bin, {}, args=["--help"])
    assert result.returncode == 0, combined(result)
    assert "Usage:" in combined(result)
    assert "--target" in combined(result)
    assert "--snapshot" in combined(result)
    assert "--list" in combined(result)


# ---------------------------------------------------------------------------
# Fail-fast: missing password
# ---------------------------------------------------------------------------

def test_requires_restic_password(stub_bin: Path, workspace: Path, repos_dir: Path) -> None:
    target = workspace / "restore-target"
    env = {**DEFAULT_SSH_ENV}
    env.pop("HOMELAB_BACKUP_RESTIC_PASSWORD", None)

    result = run_script(stub_bin, env, args=["my-data", "--target", str(target)], repos_dir=repos_dir)

    assert result.returncode != 0
    assert "HOMELAB_BACKUP_RESTIC_PASSWORD" in combined(result)


# ---------------------------------------------------------------------------
# Fail-fast: missing SSH config
# ---------------------------------------------------------------------------

def test_requires_ssh_config(stub_bin: Path, workspace: Path, repos_dir: Path) -> None:
    target = workspace / "restore-target"
    env = {
        **DEFAULT_SSH_ENV,
        "SSH_HOST": "",
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
    }

    result = run_script(stub_bin, env, args=["my-data", "--target", str(target)], repos_dir=repos_dir)

    assert result.returncode != 0
    assert "Required configuration 'SSH_HOST' is not set." in combined(result)


# ---------------------------------------------------------------------------
# Fail-fast: --target required when not listing
# ---------------------------------------------------------------------------

def test_requires_target_when_not_listing(stub_bin: Path, repos_dir: Path) -> None:
    env = {
        **DEFAULT_SSH_ENV,
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
    }

    result = run_script(stub_bin, env, args=["my-data"], repos_dir=repos_dir)

    assert result.returncode != 0
    assert "--target" in combined(result)


# ---------------------------------------------------------------------------
# Basic restore flow: restic restore called with correct args
# ---------------------------------------------------------------------------

def test_restore_flow(
    stub_bin: Path, workspace: Path, repos_dir: Path, tmp_path: Path
) -> None:
    target = workspace / "restore-target"
    restic_log = tmp_path / "restic.log"
    repo_url = "sftp:backup@backup.example.com:/srv/restic/supermicro/my-data"

    env = {
        **DEFAULT_SSH_ENV,
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
    }

    result = run_script(
        stub_bin, env,
        args=["my-data", "--target", str(target)],
        repos_dir=repos_dir,
        restic_log=restic_log,
    )

    assert result.returncode == 0, combined(result)
    calls = read_restic_log(restic_log)
    assert f"--repo {repo_url} restore latest --target {target}" in calls


# ---------------------------------------------------------------------------
# --snapshot: specific snapshot ID is forwarded to restic
# ---------------------------------------------------------------------------

def test_restore_specific_snapshot(
    stub_bin: Path, workspace: Path, repos_dir: Path, tmp_path: Path
) -> None:
    target = workspace / "restore-target"
    restic_log = tmp_path / "restic.log"
    repo_url = "sftp:backup@backup.example.com:/srv/restic/supermicro/my-data"

    env = {
        **DEFAULT_SSH_ENV,
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
    }

    result = run_script(
        stub_bin, env,
        args=["my-data", "--target", str(target), "--snapshot", "abc12345"],
        repos_dir=repos_dir,
        restic_log=restic_log,
    )

    assert result.returncode == 0, combined(result)
    calls = read_restic_log(restic_log)
    assert f"--repo {repo_url} restore abc12345 --target {target}" in calls


# ---------------------------------------------------------------------------
# --include: path filter is forwarded to restic
# ---------------------------------------------------------------------------

def test_restore_with_include(
    stub_bin: Path, workspace: Path, repos_dir: Path, tmp_path: Path
) -> None:
    target = workspace / "restore-target"
    restic_log = tmp_path / "restic.log"
    repo_url = "sftp:backup@backup.example.com:/srv/restic/supermicro/my-data"

    env = {
        **DEFAULT_SSH_ENV,
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
    }

    result = run_script(
        stub_bin, env,
        args=["my-data", "--target", str(target), "--include", "/home/nick/data/subdir"],
        repos_dir=repos_dir,
        restic_log=restic_log,
    )

    assert result.returncode == 0, combined(result)
    calls = read_restic_log(restic_log)
    assert f"--repo {repo_url} restore latest --target {target} --include /home/nick/data/subdir" in calls


# ---------------------------------------------------------------------------
# --include repeated: multiple path filters are all forwarded
# ---------------------------------------------------------------------------

def test_restore_with_multiple_includes(
    stub_bin: Path, workspace: Path, repos_dir: Path, tmp_path: Path
) -> None:
    target = workspace / "restore-target"
    restic_log = tmp_path / "restic.log"
    repo_url = "sftp:backup@backup.example.com:/srv/restic/supermicro/my-data"

    env = {
        **DEFAULT_SSH_ENV,
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
    }

    result = run_script(
        stub_bin, env,
        args=[
            "my-data", "--target", str(target),
            "--include", "/home/nick/data/a",
            "--include", "/home/nick/data/b",
        ],
        repos_dir=repos_dir,
        restic_log=restic_log,
    )

    assert result.returncode == 0, combined(result)
    calls = read_restic_log(restic_log)
    assert any(
        f"--repo {repo_url} restore latest --target {target}" in line
        and "--include /home/nick/data/a" in line
        and "--include /home/nick/data/b" in line
        for line in calls
    ), f"Expected restore call with both --include flags in:\n" + "\n".join(calls)


# ---------------------------------------------------------------------------
# --list: calls restic snapshots, no restore
# ---------------------------------------------------------------------------

def test_list_snapshots(
    stub_bin: Path, repos_dir: Path, tmp_path: Path
) -> None:
    restic_log = tmp_path / "restic.log"
    repo_url = "sftp:backup@backup.example.com:/srv/restic/supermicro/my-data"
    mark_repo_initialized(repos_dir, repo_url)

    env = {
        **DEFAULT_SSH_ENV,
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
    }

    result = run_script(
        stub_bin, env,
        args=["my-data", "--list"],
        repos_dir=repos_dir,
        restic_log=restic_log,
    )

    assert result.returncode == 0, combined(result)
    calls = read_restic_log(restic_log)
    assert any(f"--repo {repo_url} snapshots" in line for line in calls)
    assert not any("restore" in line for line in calls)


# ---------------------------------------------------------------------------
# non-standard SSH port
# ---------------------------------------------------------------------------

def test_build_repo_url_non_default_port(
    stub_bin: Path, workspace: Path, repos_dir: Path, tmp_path: Path
) -> None:
    target = workspace / "restore-target"
    restic_log = tmp_path / "restic.log"

    env = {
        **DEFAULT_SSH_ENV,
        "SSH_PORT": "2222",
        "HOMELAB_BACKUP_RESTIC_PASSWORD": "secret",
    }

    result = run_script(
        stub_bin, env,
        args=["my-data", "--target", str(target)],
        repos_dir=repos_dir,
        restic_log=restic_log,
    )

    assert result.returncode == 0, combined(result)
    calls = read_restic_log(restic_log)
    expected_url = "sftp://backup@backup.example.com:2222/srv/restic/supermicro/my-data"
    assert any(expected_url in line for line in calls), (
        f"Expected URL {expected_url!r} in:\n" + "\n".join(calls)
    )
