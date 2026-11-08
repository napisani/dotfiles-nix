"""Best-effort user-data backup, comparison and mechanical restore.

A run backs up the protected paths once, before anything changes. After the
migration it restores whatever went missing or was emptied, never overwriting a
file that is newer than its backup, and lists what needs a manual repair.
Backups are never deleted by the harness.
"""

import ctypes
import fnmatch
import multiprocessing
import os
import shutil
import stat
import sys
import tempfile
import time
import tomllib
from datetime import datetime, timezone
from pathlib import Path

from .common import HARNESS, RolloutError, home_path, move_aside, read_json, run, write_json

# Application data under these directories stays protected even when a
# regenerable pattern would match a parent.
PROTECTED_PREFIXES = [
    "Library/Preferences",
    "Library/Application Support",
    "Library/Application Scripts",
    "Library/Containers",
    "Library/Group Containers",
]


def manifest(host):
    """Protected path patterns, credentials and regenerable patterns for a host."""
    data = tomllib.loads((HARNESS / "user-data.toml").read_text())
    paths, credentials = [], []
    for app in data["apps"].values():
        paths += app.get("paths", [])
        credentials += app.get("credentials", [])
    extra = host.decisions.get("data", {})
    paths += extra.get("protected", [])
    regenerable = data.get("regenerable", {}).get("paths", []) + extra.get("regenerable", [])
    return {"paths": paths, "credentials": credentials, "regenerable": regenerable}


def matches_tree(relative, patterns):
    """Whether `relative` is, or lies under, a path matching one of the patterns."""
    for pattern in patterns:
        if not any(char in pattern for char in "*?["):
            if relative == pattern or relative.startswith(pattern + "/"):
                return True
            continue
        ancestor = relative
        while ancestor:
            if fnmatch.fnmatchcase(ancestor, pattern):
                return True
            ancestor = ancestor.rpartition("/")[0]
    return False


def regenerable(relative, spec):
    if matches_tree(relative, spec["credentials"]):
        return False
    if any(relative == prefix or prefix.startswith(relative + "/") for prefix in PROTECTED_PREFIXES):
        return False
    return matches_tree(relative, spec["regenerable"])


def protected_roots(home, spec):
    """Existing protected paths, keyed by HOME-relative path."""
    roots = {}
    for pattern in spec["paths"] + spec["credentials"]:
        home_path(home, pattern)
        for path in sorted(Path(home).glob(pattern)):
            relative = path.relative_to(home).as_posix()
            if not any(relative == root or relative.startswith(root + "/") for root in roots):
                roots[relative] = path
    return roots


def walk(home, spec, *, on_error=None, progress=None):
    """Entries for every backed-up path: kind, mode, size, mtime and link target."""
    entries = {}
    prefix = len(str(home)) + 1
    stack = [str(path) for path in reversed(list(protected_roots(home, spec).values()))]
    while stack:
        path = stack.pop()
        relative = path[prefix:]
        if relative in entries or regenerable(relative, spec):
            continue
        info = os.lstat(path)
        entry = {"mode": stat.S_IMODE(info.st_mode), "mtime_ns": info.st_mtime_ns}
        if stat.S_ISLNK(info.st_mode):
            entries[relative] = {**entry, "kind": "link", "target": os.readlink(path)}
        elif stat.S_ISDIR(info.st_mode):
            entries[relative] = {**entry, "kind": "directory"}
            if progress:
                progress(relative)
            try:
                children = sorted(os.listdir(path), reverse=True)
            except PermissionError as error:
                if on_error is None:
                    raise
                on_error(relative, error)
                continue
            stack.extend(os.path.join(path, child) for child in children)
        elif stat.S_ISREG(info.st_mode):
            entries[relative] = {
                **entry, "kind": "file", "bytes": info.st_size,
                "allocated_bytes": info.st_blocks * 512,
                "credential": matches_tree(relative, spec["credentials"]),
            }
    return entries


def clone(source, target):
    """APFS clone on macOS, a plain copy elsewhere; never falls back to a disk-filling copy."""
    if sys.platform != "darwin":
        shutil.copy2(source, target, follow_symlinks=False)
        return
    clonefile = ctypes.CDLL(None, use_errno=True).clonefile
    clonefile.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint32]
    clonefile.restype = ctypes.c_int
    # CLONE_NOFOLLOW | CLONE_NOOWNERCOPY
    if clonefile(os.fsencode(source), os.fsencode(target), 0x0001 | 0x0002) != 0:
        error = ctypes.get_errno()
        raise OSError(error, f"APFS clone failed; no full-copy fallback: {os.strerror(error)}", str(target))


def _estimate_worker(home, host, result_file, progress_file):
    unreadable = []

    def note(relative):
        Path(progress_file).write_text(relative)

    entries = walk(Path(home), manifest(host), on_error=lambda relative, error: unreadable.append(relative),
                   progress=note)
    files = [entry for entry in entries.values() if entry["kind"] == "file"]
    write_json(result_file, {
        "files": len(files),
        "bytes": sum(entry["bytes"] for entry in files),
        "allocated_bytes": sum(entry["allocated_bytes"] for entry in files),
        "unreadable": unreadable,
    })


def estimate(home, host, timeout=900):
    """Backup size from metadata only, plus paths the user's account cannot read.

    The walk runs in a child process: a macOS privacy prompt blocks a directory
    read indefinitely, and the blocked directory is reported instead of hanging.
    """
    with tempfile.TemporaryDirectory(prefix="mise-estimate-") as scratch:
        result_file, progress_file = Path(scratch) / "result.json", Path(scratch) / "progress"
        worker = multiprocessing.get_context("spawn").Process(
            target=_estimate_worker, args=(str(home), host, str(result_file), str(progress_file)))
        worker.start()
        worker.join(timeout)
        if worker.is_alive():
            worker.kill()
            worker.join()
            blocked = progress_file.read_text() if progress_file.exists() else "?"
            return {"files": 0, "bytes": 0, "allocated_bytes": 0, "unreadable": [],
                    "blocked": f"{blocked} (a macOS privacy prompt or Full Disk Access is needed)"}
        if not result_file.exists():
            raise RolloutError("backup estimate failed; run the walk directly to see why")
        return read_json(result_file)


def backup(run_dir, home, host):
    """Backs up protected data once per run; an existing backup is kept as is."""
    run_dir, home = Path(run_dir), Path(home)
    record = run_dir / "backup/backup.json"
    if record.exists():
        return read_json(record)
    files = run_dir / "backup/files"
    if files.exists():
        raise RolloutError(f"incomplete earlier backup at {files}; review and move it aside")
    files.mkdir(parents=True, mode=0o700)
    entries = walk(home, manifest(host))
    for relative, entry in entries.items():
        target = files / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if entry["kind"] == "directory":
            target.mkdir(exist_ok=True)
        elif entry["kind"] == "link":
            target.symlink_to(entry["target"])
        else:
            clone(home / relative, target)
            os.utime(target, ns=(entry["mtime_ns"], entry["mtime_ns"]), follow_symlinks=False)
    for relative, entry in reversed(list(entries.items())):
        if entry["kind"] == "directory":
            os.chmod(files / relative, entry["mode"])
    result = {
        "home": str(home),
        "created": datetime.now(timezone.utc).isoformat(),
        "method": "apfs-clone" if sys.platform == "darwin" else "copy",
        "entries": entries,
    }
    write_json(record, result)
    return result


def local_snapshot():
    """Attempts an APFS local snapshot and records whether, and how, it was taken."""
    if sys.platform != "darwin":
        return {"taken": False, "reason": "not macOS"}
    attempts = []
    for prefix in ([], ["sudo", "-n"]):
        result = run([*prefix, "/usr/bin/tmutil", "localsnapshot"], check=False)
        attempts.append({"sudo": bool(prefix), "exit": result.returncode,
                         "output": (result.stdout + result.stderr).strip()[-300:]})
        if result.returncode == 0:
            listing = run(["/usr/bin/tmutil", "listlocalsnapshots", "/"], check=False).stdout
            return {"taken": True, "needs_admin": bool(prefix), "attempts": attempts,
                    "snapshots": listing.split()[-3:],
                    "retention": "macOS keeps local snapshots about 24 hours, less under disk pressure"}
    return {"taken": False, "attempts": attempts}


def nightly_backup(path="/media/storage/computer_backups/supermicro/home"):
    """Date of supermicro's nightly home rsync, read from the backup directory."""
    target = Path(path)
    if not target.is_dir():
        return {"present": False, "path": path}
    # rsync keeps file times, so the directory's own time marks the last run too.
    newest = max([target.stat().st_mtime, *(child.lstat().st_mtime for child in target.iterdir())])
    stamp = datetime.fromtimestamp(newest, timezone.utc)
    return {"present": True, "path": path, "newest": stamp.isoformat(),
            "age_hours": round((time.time() - newest) / 3600, 1)}


def compare_and_restore(run_dir, home, *, apply=True):
    """Restores missing or emptied backed-up paths; lists conflicts for manual repair."""
    run_dir, home = Path(run_dir), Path(home)
    saved = read_json(run_dir / "backup/backup.json")
    files = run_dir / "backup/files"
    restored, manual = [], []
    for relative, entry in saved["entries"].items():
        path = home / relative
        kind = entry["kind"]
        exists = path.exists() or path.is_symlink()
        if kind == "directory":
            if not exists:
                if apply:
                    path.mkdir(parents=True, mode=entry["mode"])
                restored.append(relative)
            elif path.is_symlink() or not path.is_dir():
                manual.append({"path": relative, "reason": "directory replaced by another type"})
            continue
        if kind == "link":
            if not exists:
                if apply:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.symlink_to(entry["target"])
                restored.append(relative)
            elif not path.is_symlink():
                manual.append({"path": relative, "reason": "link replaced by a file or directory"})
            continue
        if not exists:
            if apply:
                path.parent.mkdir(parents=True, exist_ok=True)
                clone(files / relative, path)
            restored.append(relative)
            continue
        if path.is_symlink() or not path.is_file():
            manual.append({"path": relative, "reason": "file replaced by another type"})
            continue
        info = path.stat()
        if info.st_size == 0 and entry["bytes"] > 0:
            if info.st_mtime_ns > entry["mtime_ns"]:
                manual.append({"path": relative, "reason": "emptied, and newer than the backup"})
                continue
            if apply:
                move_aside(path, run_dir, relative)
                clone(files / relative, path)
            restored.append(relative)
    result = {"restored": restored, "manual": manual}
    if apply:
        write_json(run_dir / "restore.json", result)
    return result
