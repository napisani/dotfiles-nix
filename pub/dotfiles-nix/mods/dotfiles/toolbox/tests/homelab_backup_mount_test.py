#!/usr/bin/env python3
"""
Tests for the NFS mount command in homelab_backup.py

Run with:
    uv run --with pytest pytest mods/dotfiles/toolbox/tests/homelab_backup_mount_test.py -v
"""

from __future__ import annotations

import importlib.util
import logging
import os
import subprocess
import sys
import types
from pathlib import Path


SCRIPT = Path(__file__).parent.parent / "homelab_backup.py"


def load_module(module_name: str):
    click = types.ModuleType("click")
    httpx = types.ModuleType("httpx")

    def identity_decorator(*_args, **_kwargs):
        def decorator(fn):
            return fn

        return decorator

    def group_decorator(*_args, **_kwargs):
        def decorator(fn):
            def command(*__args, **__kwargs):
                return identity_decorator(*__args, **__kwargs)

            fn.command = command
            return fn

        return decorator

    setattr(click, "group", group_decorator)
    setattr(click, "option", identity_decorator)
    setattr(click, "pass_context", identity_decorator)
    setattr(click, "Context", object)
    setattr(httpx, "post", lambda *args, **kwargs: None)

    sys.modules.setdefault("click", click)
    sys.modules.setdefault("httpx", httpx)

    spec = importlib.util.spec_from_file_location(module_name, SCRIPT)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_do_mount_passes_addr_option(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("NFS_HOST", "192.168.0.138")
    monkeypatch.setenv("NFS_EXPORT", "/homelab-backup")
    monkeypatch.setenv("NFS_MOUNT_POINT", str(tmp_path / "restic"))
    monkeypatch.setenv("NFS_OPTIONS", "_netdev,rw")

    backup = load_module("homelab_backup_mount_test")
    commands: list[list[str]] = []

    def fake_run(cmd: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        commands.append(cmd)
        return subprocess.CompletedProcess(cmd, 0)

    monkeypatch.setattr(backup, "is_mounted", lambda: False)
    monkeypatch.setattr(backup.subprocess, "run", fake_run)

    assert backup.do_mount() is True
    assert commands == [
        [
            "mount",
            "-t",
            "nfs",
            "-o",
            "_netdev,rw,addr=192.168.0.138",
            "192.168.0.138:/homelab-backup",
            str(tmp_path / "restic"),
        ]
    ]


def test_do_mount_retries_with_explicit_nfs_version(
    monkeypatch, tmp_path: Path
) -> None:
    monkeypatch.setenv("NFS_HOST", "192.168.0.138")
    monkeypatch.setenv("NFS_EXPORT", "/homelab-backup")
    monkeypatch.setenv("NFS_MOUNT_POINT", str(tmp_path / "restic"))
    monkeypatch.setenv("NFS_OPTIONS", "_netdev,rw")

    backup = load_module("homelab_backup_mount_test_retry")
    commands: list[list[str]] = []

    def fake_run(cmd: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        commands.append(cmd)
        if len(commands) == 1:
            return subprocess.CompletedProcess(
                cmd,
                32,
                stderr="mount: /mnt/restic: fsconfig() failed: NFS: Version unavailable.",
            )
        return subprocess.CompletedProcess(cmd, 0)

    monkeypatch.setattr(backup, "is_mounted", lambda: False)
    monkeypatch.setattr(backup.subprocess, "run", fake_run)

    assert backup.do_mount() is True
    assert commands == [
        [
            "mount",
            "-t",
            "nfs",
            "-o",
            "_netdev,rw,addr=192.168.0.138",
            "192.168.0.138:/homelab-backup",
            str(tmp_path / "restic"),
        ],
        [
            "mount",
            "-t",
            "nfs",
            "-o",
            "_netdev,rw,addr=192.168.0.138,vers=4.1",
            "192.168.0.138:/homelab-backup",
            str(tmp_path / "restic"),
        ],
    ]


def test_do_mount_falls_back_to_nfs3_after_nfs4_path_failure(
    monkeypatch, tmp_path: Path
) -> None:
    monkeypatch.setenv("NFS_HOST", "192.168.0.138")
    monkeypatch.setenv("NFS_EXPORT", "/homelab-backup")
    monkeypatch.setenv("NFS_MOUNT_POINT", str(tmp_path / "restic"))
    monkeypatch.setenv("NFS_OPTIONS", "_netdev,rw")

    backup = load_module("homelab_backup_mount_test_nfs3_retry")
    commands: list[list[str]] = []

    def fake_run(cmd: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        commands.append(cmd)
        if len(commands) == 1:
            return subprocess.CompletedProcess(
                cmd,
                32,
                stderr="mount: /mnt/restic: fsconfig() failed: NFS: Version unavailable.",
            )
        if len(commands) == 2:
            return subprocess.CompletedProcess(
                cmd,
                32,
                stderr="mount: /mnt/restic: fsconfig() failed: NFS4: Couldn't follow remote path.",
            )
        return subprocess.CompletedProcess(cmd, 0)

    monkeypatch.setattr(backup, "is_mounted", lambda: False)
    monkeypatch.setattr(backup.subprocess, "run", fake_run)

    assert backup.do_mount() is True
    assert commands == [
        [
            "mount",
            "-t",
            "nfs",
            "-o",
            "_netdev,rw,addr=192.168.0.138",
            "192.168.0.138:/homelab-backup",
            str(tmp_path / "restic"),
        ],
        [
            "mount",
            "-t",
            "nfs",
            "-o",
            "_netdev,rw,addr=192.168.0.138,vers=4.1",
            "192.168.0.138:/homelab-backup",
            str(tmp_path / "restic"),
        ],
        [
            "mount",
            "-t",
            "nfs",
            "-o",
            "_netdev,rw,addr=192.168.0.138,vers=3",
            "192.168.0.138:/homelab-backup",
            str(tmp_path / "restic"),
        ],
    ]


def test_do_mount_logs_read_only_export_guidance(
    monkeypatch, tmp_path: Path, caplog
) -> None:
    monkeypatch.setenv("NFS_HOST", "192.168.0.138")
    monkeypatch.setenv("NFS_EXPORT", "/homelab-backup")
    monkeypatch.setenv("NFS_MOUNT_POINT", str(tmp_path / "restic"))
    monkeypatch.setenv("NFS_OPTIONS", "_netdev,rw")

    backup = load_module("homelab_backup_mount_test_read_only")

    def fake_run(cmd: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(
            cmd,
            32,
            stderr=(
                "mount: /mnt/restic: cannot mount 192.168.0.138:/homelab-backup read-only."
            ),
        )

    monkeypatch.setattr(backup, "is_mounted", lambda: False)
    monkeypatch.setattr(backup.subprocess, "run", fake_run)

    with caplog.at_level(logging.ERROR):
        assert backup.do_mount() is False

    assert (
        "NFS export is read-only for this client; restic backup requires write access."
        in caplog.text
    )
