#!/usr/bin/env -S uv run
# /// script
# requires-python = "==3.12"
# dependencies = ["click"]
# ///
"""
Restore a restic snapshot from a remote SSH repository to a local directory.

Usage examples:

  # Restore the latest snapshot of 'my-data' into /tmp/restore
  homelab_restore.py my-data --target /tmp/restore

  # Restore a specific snapshot
  homelab_restore.py my-data --target /tmp/restore --snapshot abc12345

  # Restore only a specific path from within the snapshot
  homelab_restore.py my-data --target /tmp/restore --include /home/nick/data/subdir

  # List available snapshots without restoring
  homelab_restore.py my-data --list
"""

from __future__ import annotations

import logging
import os
import subprocess
import sys
from pathlib import Path

import click

# ── Configuration ──────────────────────────────────────────────────────────
# Edit these defaults. Any value can be overridden via an environment variable
# of the same name (e.g.  SSH_HOST=myserver.local ./homelab_restore.py).

SSH_HOST         = os.environ.get("SSH_HOST",         "backup.example.com")
SSH_USER         = os.environ.get("SSH_USER",         "nick")
SSH_PORT         = os.environ.get("SSH_PORT",         "22")
REMOTE_REPO_BASE = os.environ.get("REMOTE_REPO_BASE", "/srv/restic/supermicro")

LOG_FILE            = os.environ.get("LOG_FILE",            "")
RESTIC_PASSWORD_ENV = os.environ.get("RESTIC_PASSWORD_ENV", "HOMELAB_BACKUP_RESTIC_PASSWORD")
# ── End of configuration ───────────────────────────────────────────────────


def setup_logging(log_file: str) -> None:
    handlers: list[logging.Handler] = [logging.StreamHandler(sys.stdout)]

    if log_file:
        try:
            log_path = Path(log_file)
            log_path.parent.mkdir(parents=True, exist_ok=True)
            log_path.touch()
            handlers.append(logging.FileHandler(log_file))
        except OSError as exc:
            print(f"[WARN] Unable to write to log file {log_file}: {exc}", file=sys.stderr)

    logging.basicConfig(
        level=logging.INFO,
        format="[%(asctime)s] [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=handlers,
        force=True,
    )


def require_restic_password() -> None:
    value = os.environ.get(RESTIC_PASSWORD_ENV, "")
    if not value:
        logging.error("Required environment variable '%s' is not set.", RESTIC_PASSWORD_ENV)
        sys.exit(1)
    os.environ["RESTIC_PASSWORD"] = value


def require_ssh_config() -> None:
    for name, value in [
        ("SSH_HOST", SSH_HOST),
        ("SSH_USER", SSH_USER),
        ("SSH_PORT", SSH_PORT),
        ("REMOTE_REPO_BASE", REMOTE_REPO_BASE),
    ]:
        if not value:
            logging.error("Required configuration '%s' is not set.", name)
            sys.exit(1)


def build_repo_url(repo_name: str) -> str:
    base = REMOTE_REPO_BASE.rstrip("/")
    if SSH_PORT and SSH_PORT != "22":
        return f"sftp://{SSH_USER}@{SSH_HOST}:{SSH_PORT}{base}/{repo_name}"
    return f"sftp:{SSH_USER}@{SSH_HOST}:{base}/{repo_name}"


def run_list(repo_url: str) -> int:
    """Print available snapshots for repo_url. Returns restic's exit code."""
    return subprocess.run(["restic", "--repo", repo_url, "snapshots"]).returncode


def run_restore(
    repo_url: str,
    snapshot: str,
    target: Path,
    include_paths: tuple[str, ...],
) -> int:
    """Restore snapshot to target. Returns restic's exit code."""
    target.mkdir(parents=True, exist_ok=True)

    cmd = ["restic", "--repo", repo_url, "restore", snapshot, "--target", str(target)]
    for path in include_paths:
        cmd.extend(["--include", path])

    return subprocess.run(cmd).returncode


@click.command(name="homelab_restore.py")
@click.argument("repo_name")
@click.option(
    "--target",
    "target_dir",
    default=None,
    help="Local directory to restore into (required unless --list is given).",
)
@click.option(
    "--snapshot",
    default="latest",
    show_default=True,
    help="Snapshot ID to restore.",
)
@click.option(
    "--include",
    "include_paths",
    multiple=True,
    metavar="PATH",
    help="Restore only paths matching this pattern. Can be repeated.",
)
@click.option(
    "--list",
    "list_only",
    is_flag=True,
    help="List available snapshots for REPO_NAME instead of restoring.",
)
@click.option(
    "--log-file",
    default=LOG_FILE,
    help="Write logs to the given file.",
)
def main(
    repo_name: str,
    target_dir: str | None,
    snapshot: str,
    include_paths: tuple[str, ...],
    list_only: bool,
    log_file: str,
) -> None:
    """Restore a restic snapshot from a remote SSH repository.

    REPO_NAME is the short repository name used in homelab_backup.py
    (e.g. 'local_kube_data', 'storage').
    """
    setup_logging(log_file)

    require_restic_password()
    require_ssh_config()

    repo_url = build_repo_url(repo_name)

    if list_only:
        sys.exit(run_list(repo_url))

    if not target_dir:
        raise click.UsageError("--target is required when not using --list.")

    target = Path(target_dir)
    logging.info("Restoring snapshot '%s' from '%s' into '%s'.", snapshot, repo_url, target)

    rc = run_restore(repo_url, snapshot, target, include_paths)
    if rc != 0:
        logging.error("restic restore exited with status %d.", rc)
    else:
        logging.info("Restore complete.")
    sys.exit(rc)


if __name__ == "__main__":
    main()
