#!/usr/bin/env -S uv run
# /// script
# requires-python = "==3.12"
# dependencies = ["click", "httpx"]
# ///
"""
Restic backup to an NFS-mounted repository.

All user-editable configuration lives in the block below.
Every value can be overridden by an environment variable of the same name.
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
# of the same name (e.g.  NFS_HOST=192.168.1.99 ./homelab_backup.py backup).

NFS_HOST = os.environ.get("NFS_HOST", "192.168.0.138")
NFS_EXPORT = os.environ.get("NFS_EXPORT", "/volume1/homelab-backup")
NFS_MOUNT_POINT = os.environ.get("NFS_MOUNT_POINT", "/mnt/restic")
NFS_OPTIONS = os.environ.get("NFS_OPTIONS", "_netdev,rw")

_STORAGE_MOUNT_POINT = os.environ.get("STORAGE_MOUNT_POINT", "/media/storage")

LOG_FILE = os.environ.get("LOG_FILE", "/var/log/backup.py.log")
RESTIC_PASSWORD_ENV = os.environ.get(
    "RESTIC_PASSWORD_ENV", "HOMELAB_BACKUP_RESTIC_PASSWORD"
)
RESTIC_KEEP_LAST = int(os.environ.get("RESTIC_KEEP_LAST", "5"))
NTFY_TOPIC = os.environ.get("NTFY_TOPIC", "https://ntfy.napisani.xyz/backups")
TAG = "[restic-backup]"

_backup_sources_json = os.environ.get("BACKUP_SOURCES_JSON", "")
BACKUP_SOURCES: list[str] = (
    json.loads(_backup_sources_json)
    if _backup_sources_json
    else [
        "/home/nick/local_kube_data",
        "/home/nick/local_kube_config",
        f"{_STORAGE_MOUNT_POINT}",
    ]
)
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


def nfs_device() -> str:
    return f"{NFS_HOST}:{NFS_EXPORT}"


def nfs_mount_options() -> str:
    options = [opt.strip() for opt in NFS_OPTIONS.split(",") if opt.strip()]
    if not any(opt.startswith("addr=") for opt in options):
        options.append(f"addr={NFS_HOST}")
    return ",".join(options)


def has_nfs_version_option(options: str) -> bool:
    return any(
        opt.startswith(("vers=", "nfsvers="))
        for opt in options.split(",")
        if opt.strip()
    )


def append_nfs_version_option(options: str, version: str) -> str:
    parts = [opt.strip() for opt in options.split(",") if opt.strip()]
    parts = [opt for opt in parts if not opt.startswith(("vers=", "nfsvers="))]
    parts.append(f"vers={version}")
    return ",".join(parts)


def run_mount(device: str, mount_options: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["mount", "-t", "nfs", "-o", mount_options, device, NFS_MOUNT_POINT],
        capture_output=True,
        text=True,
    )


def is_mounted() -> bool:
    """Return True if NFS_MOUNT_POINT is currently an active mount."""
    result = subprocess.run(
        ["mountpoint", "-q", NFS_MOUNT_POINT],
        capture_output=True,
    )
    return result.returncode == 0


def do_mount() -> bool:
    """Mount the NFS share. Returns True on success."""
    mount_point = Path(NFS_MOUNT_POINT)
    if not mount_point.exists():
        logging.info("Creating mount point %s", NFS_MOUNT_POINT)
        try:
            mount_point.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            logging.error("Failed to create mount point: %s", exc)
            return False

    if is_mounted():
        logging.info("NFS share already mounted at %s", NFS_MOUNT_POINT)
        return True

    device = nfs_device()
    mount_options = nfs_mount_options()
    logging.info(
        "Mounting %s -> %s (options: %s)", device, NFS_MOUNT_POINT, mount_options
    )
    result = run_mount(device, mount_options)
    if result.returncode != 0 and not has_nfs_version_option(mount_options):
        stderr = (result.stderr or "").strip()
        if "Version unavailable" in stderr:
            retry_options = append_nfs_version_option(mount_options, "4.1")
            logging.info(
                "Retrying mount with explicit NFS version (options: %s)",
                retry_options,
            )
            result = run_mount(device, retry_options)
            stderr = (result.stderr or "").strip()
            if result.returncode != 0 and "Couldn't follow remote path" in stderr:
                retry_options = append_nfs_version_option(mount_options, "3")
                logging.info(
                    "Retrying mount with NFSv3 path semantics (options: %s)",
                    retry_options,
                )
                result = run_mount(device, retry_options)

    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        if stderr:
            logging.error(stderr)
            if "read-only" in stderr:
                logging.error(
                    "NFS export is read-only for this client; restic backup requires write access."
                )
        logging.error("Failed to mount NFS share (exit code %d).", result.returncode)
        return False

    logging.info("NFS share mounted successfully.")
    return True


def do_unmount(lazy: bool = False) -> bool:
    """Unmount the NFS share. Returns True on success."""
    if not is_mounted():
        logging.info("NFS share is not mounted at %s", NFS_MOUNT_POINT)
        return True

    logging.info("Unmounting %s", NFS_MOUNT_POINT)
    cmd = ["umount"]
    if lazy:
        cmd.append("-l")
    cmd.append(NFS_MOUNT_POINT)
    result = subprocess.run(cmd)
    if result.returncode != 0:
        logging.error("Failed to unmount NFS share (exit code %d).", result.returncode)
        return False

    logging.info("NFS share unmounted successfully.")
    return True


def repo_path() -> str:
    return NFS_MOUNT_POINT.rstrip("/")


def repo_exists() -> bool:
    result = subprocess.run(
        ["restic", "--repo", repo_path(), "snapshots"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def run_restic(operation: str, *args: str, dry_run: bool = False) -> bool:
    repo = repo_path()

    if dry_run and operation == "init":
        logging.info("Dry run: would initialize restic repository at '%s'.", repo)
        return True

    cmd = ["restic", "--repo", repo, operation]
    cmd.extend(args)

    if dry_run and operation in ("backup", "forget"):
        cmd.append("--dry-run")

    result = subprocess.run(cmd)
    return result.returncode == 0


def do_backup(sources: list[str], dry_run: bool) -> bool:
    """Run backup + forget for every source. Returns True if all succeeded."""
    all_ok = True
    for index, source in enumerate(sources, start=1):
        source = source.rstrip("/")
        logging.info("Backing up source #%d: %s", index, source)

        if not Path(source).is_dir():
            logging.error(
                "Source #%d: directory '%s' does not exist — skipping.", index, source
            )
            all_ok = False
            continue

        if not run_restic("backup", "--tag", "auto", source, dry_run=dry_run):
            logging.error("Source #%d: backup failed for '%s'.", index, source)
            all_ok = False

    return all_ok


def do_forget(dry_run: bool) -> bool:
    """Run forget with the configured retention policy."""
    return run_restic(
        "forget",
        "--tag",
        "auto",
        "--keep-last",
        str(RESTIC_KEEP_LAST),
        dry_run=dry_run,
    )


def do_prune(dry_run: bool) -> bool:
    """Run prune (only on Sundays unless forced)."""
    if dry_run:
        logging.info("Dry run: skipping prune.")
        return True
    return run_restic("prune")


# ── CLI ────────────────────────────────────────────────────────────────────


@click.group()
@click.option(
    "--log-file", default=LOG_FILE, help=f"Log file path (default: {LOG_FILE})."
)
@click.pass_context
def cli(ctx: click.Context, log_file: str) -> None:
    """Restic backup tool using an NFS-mounted repository."""
    ctx.ensure_object(dict)
    ctx.obj["log_file"] = log_file
    setup_logging(log_file)


@cli.command()
def mount() -> None:
    """Mount the NFS backup share."""
    require_command("mount")
    if not do_mount():
        sys.exit(1)


@cli.command()
@click.option("--lazy", is_flag=True, default=False, help="Use lazy unmount (-l).")
def unmount(lazy: bool) -> None:
    """Unmount the NFS backup share."""
    require_command("umount")
    if not do_unmount(lazy=lazy):
        sys.exit(1)


@cli.command()
@click.option(
    "--dry-run",
    is_flag=True,
    default=False,
    help="Show what would happen without changes.",
)
@click.option(
    "--no-prune", is_flag=True, default=False, help="Skip the weekly prune step."
)
def backup(dry_run: bool, no_prune: bool) -> None:
    """Mount NFS, run restic backup/forget/prune, then unmount."""
    require_command("restic")
    require_command("mount")
    require_command("umount")
    require_restic_password()

    if not BACKUP_SOURCES:
        logging.error(
            "No backup sources defined. Update BACKUP_SOURCES near the top of the script."
        )
        sys.exit(1)

    logging.info("Starting restic backup. Dry run: %s.", dry_run)
    if NTFY_TOPIC:
        notify("START", f"Restic backup job started. Dry run: {dry_run}.")

    # ── Mount ──
    if not do_mount():
        if NTFY_TOPIC:
            notify("ERROR", "Failed to mount NFS share.")
        sys.exit(1)

    try:
        # ── Init if needed ──
        if not repo_exists():
            logging.info("Initializing restic repository at '%s'.", repo_path())
            if not run_restic("init", dry_run=dry_run):
                logging.error("Failed to initialize repository.")
                if NTFY_TOPIC:
                    notify("ERROR", "Failed to initialize restic repository.")
                sys.exit(1)

        # ── Backup ──
        backup_ok = do_backup(BACKUP_SOURCES, dry_run)

        # ── Forget ──
        forget_ok = do_forget(dry_run)
        if not forget_ok:
            logging.error("Forget step failed.")

        # ── Prune (Sundays only, unless --no-prune) ──
        prune_ok = True
        if not no_prune:
            if datetime.now().weekday() == 6:  # Sunday
                logging.info("Sunday: running prune.")
                prune_ok = do_prune(dry_run)
                if not prune_ok:
                    logging.error("Prune step failed.")
            else:
                logging.info("Not Sunday: skipping prune.")

        all_ok = backup_ok and forget_ok and prune_ok

    finally:
        # ── Always unmount ──
        do_unmount()

    if all_ok:
        logging.info("Restic backup completed successfully.")
        if NTFY_TOPIC:
            notify("SUCCESS", "Restic backup completed successfully.")
    else:
        logging.error("Restic backup completed with errors.")
        if NTFY_TOPIC:
            notify("ERROR", "Restic backup completed with errors.")
        sys.exit(1)


if __name__ == "__main__":
    cli()
