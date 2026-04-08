#!/usr/bin/env -S uv run
# /// script
# requires-python = "==3.12"
# dependencies = ["click", "httpx"]
# ///
"""
Restic backup to remote SSH repositories.

All user-editable configuration lives in the block below.
Every value can be overridden by an environment variable of the same name,
which is useful for testing and one-off overrides.
"""

from __future__ import annotations

import json
import logging
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import click
import httpx

# ── Configuration ──────────────────────────────────────────────────────────
# Edit these defaults. Any value can be overridden via an environment variable
# of the same name (e.g.  SSH_HOST=myserver.local ./backup.py).

_STORAGE_MOUNT_POINT = os.environ.get("STORAGE_MOUNT_POINT", "/media/storage")

SSH_HOST         = os.environ.get("SSH_HOST",         "backup.example.com")
SSH_USER         = os.environ.get("SSH_USER",         "nick")
SSH_PORT         = os.environ.get("SSH_PORT",         "22")
REMOTE_REPO_BASE = os.environ.get("REMOTE_REPO_BASE", "/srv/restic/supermicro")

LOG_FILE             = os.environ.get("LOG_FILE",             "/var/log/backup.py.log")
RESTIC_PASSWORD_ENV  = os.environ.get("RESTIC_PASSWORD_ENV",  "HOMELAB_BACKUP_RESTIC_PASSWORD")
RESTIC_KEEP_LAST     = int(os.environ.get("RESTIC_KEEP_LAST", "5"))
NTFY_TOPIC           = os.environ.get("NTFY_TOPIC",           "https://ntfy.napisani.xyz/backups")
TAG                  = "[restic-backup]"

_backup_pairs_json = os.environ.get("BACKUP_PAIRS_JSON", "")
BACKUP_PAIRS: list[str] = json.loads(_backup_pairs_json) if _backup_pairs_json else [
    "/home/nick/local_kube_data:local_kube_data",
    "/home/nick/local_kube_config:home_local_kube_config",
    f"{_STORAGE_MOUNT_POINT}:storage",
]
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
            print(
                f"[WARN] Unable to write to log file {log_file}: {exc}",
                file=sys.stderr,
            )

    logging.basicConfig(
        level=logging.INFO,
        format="[%(asctime)s] [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=handlers,
        force=True,
    )


def notify(status: str, message: str) -> None:
    if not NTFY_TOPIC:
        return
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    payload = f"{timestamp} {TAG} [{status}] {message}"
    try:
        httpx.post(
            NTFY_TOPIC,
            content=payload.encode(),
            headers={"Content-Type": "text/plain; charset=utf-8"},
            timeout=10.0,
        )
    except Exception as exc:  # noqa: BLE001
        logging.warning("Failed to send notification: %s", exc)


def require_command(cmd: str) -> None:
    import shutil

    if not shutil.which(cmd):
        logging.error("Required command '%s' not found in PATH.", cmd)
        sys.exit(1)


def require_restic_password() -> None:
    value = os.environ.get(RESTIC_PASSWORD_ENV, "")
    if not value:
        logging.error(
            "Required environment variable '%s' is not set.", RESTIC_PASSWORD_ENV
        )
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


def repo_exists(repo: str) -> bool:
    result = subprocess.run(
        ["restic", "--repo", repo, "snapshots"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def run_restic(repo: str, operation: str, *args: str, dry_run: bool = False) -> bool:
    if dry_run and operation == "init":
        logging.info(
            "Dry run: would initialize restic repository at '%s'.", repo
        )
        return True

    cmd = ["restic", "--repo", repo, operation]
    cmd.extend(args)

    if dry_run and operation in ("backup", "forget"):
        cmd.append("--dry-run")

    result = subprocess.run(cmd)
    return result.returncode == 0


def validate_pairs(pairs: list[str]) -> None:
    if not pairs:
        logging.error(
            "No backup pairs defined. Update the BACKUP_PAIRS list near the top of the script."
        )
        sys.exit(1)

    for index, pair in enumerate(pairs, start=1):
        if ":" not in pair:
            logging.error(
                "Backup pair #%d ('%s') is invalid. Expected format 'source:repo-name'.",
                index,
                pair,
            )
            sys.exit(1)

        source, _, repo_name = pair.partition(":")
        if not source.rstrip("/") or not repo_name.rstrip("/"):
            logging.error(
                "Source and repo name must be non-empty for pair #%d ('%s').",
                index,
                pair,
            )
            sys.exit(1)


def process_pair(
    index: int,
    source: str,
    repo_name: str,
    dry_run: bool,
    pair_failures: list[int],
) -> None:
    source = source.rstrip("/")
    repo_url = build_repo_url(repo_name)

    logging.info("Preparing pair #%d: %s -> %s", index, source, repo_url)

    if not Path(source).is_dir():
        pair_failures.append(index)
        logging.error(
            "Pair #%d failed: Source directory '%s' does not exist.", index, source
        )
        return

    repo_missing = not repo_exists(repo_url)

    if repo_missing:
        logging.info("Repository '%s' is not initialized yet.", repo_url)
        if not run_restic(repo_url, "init", dry_run=dry_run):
            pair_failures.append(index)
            logging.error(
                "Pair #%d failed: Failed to initialize repository '%s'.",
                index,
                repo_url,
            )
            return

    if dry_run and repo_missing:
        logging.info(
            "Dry run: skipping backup and forget for '%s' until the repository exists.",
            repo_url,
        )
        logging.info("Pair #%d completed successfully.", index)
        return

    if not run_restic(repo_url, "backup", source, dry_run=dry_run):
        pair_failures.append(index)
        logging.error(
            "Pair #%d failed: Failed to back up '%s' to '%s'.", index, source, repo_url
        )
        return

    if not run_restic(
        repo_url, "forget", "--keep-last", str(RESTIC_KEEP_LAST), "--prune", dry_run=dry_run
    ):
        pair_failures.append(index)
        logging.error(
            "Pair #%d failed: Failed to prune repository '%s'.", index, repo_url
        )
        return

    logging.info("Pair #%d completed successfully.", index)


@click.command(name="backup.py")
@click.option(
    "--dry-run",
    is_flag=True,
    default=False,
    help="Show what would be backed up without making changes.",
)
@click.option(
    "--log-file",
    default=LOG_FILE,
    help=f"Write logs to the given file (default: {LOG_FILE}).",
)
def main(dry_run: bool, log_file: str) -> None:
    """Restic backup to remote SSH repositories.

    Backup pairs are configured near the top of this script as
    source:repo-name entries. Each run creates a restic snapshot in a
    remote SSH-backed repository.
    """
    setup_logging(log_file)

    pair_failures: list[int] = []

    require_command("restic")
    require_restic_password()
    require_ssh_config()
    validate_pairs(BACKUP_PAIRS)

    logging.info("Starting restic backup. Dry run: %s.", dry_run)

    if NTFY_TOPIC:
        notify("START", f"Restic backup job started. Dry run: {dry_run}.")

    logging.info("Validated %d backup pair(s).", len(BACKUP_PAIRS))

    for index, pair in enumerate(BACKUP_PAIRS, start=1):
        source, _, repo_name = pair.partition(":")
        process_pair(index, source.rstrip("/"), repo_name.rstrip("/"), dry_run, pair_failures)

    if pair_failures:
        count = len(pair_failures)
        logging.error("Backup completed with %d failed pair(s).", count)
        if NTFY_TOPIC:
            notify("ERROR", f"Restic backup completed with {count} failed pair(s).")
        sys.exit(1)

    logging.info("Restic backup completed successfully.")
    if NTFY_TOPIC:
        notify("SUCCESS", "Restic backup completed successfully.")


if __name__ == "__main__":
    main()
