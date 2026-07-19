#!/usr/bin/env python3
"""
Run homelab commands locally when possible, or over SSH when needed.
"""

from __future__ import annotations

import argparse
import json
import re
import shlex
import socket
import subprocess
import sys
import time
from dataclasses import dataclass
from typing import Any

SERVERS: dict[str, dict[str, list[str] | str]] = {
    "supermicro": {
        "user": "nick",
        "local_hostnames": ["supermicro"],
        "candidates": ["supermicro", "192.168.1.51"],
        "tailscale_names": ["supermicro"],
        "tailscale_fallbacks": [],
    },
    "maclab": {
        "user": "nick",
        "local_hostnames": ["maclab"],
        "candidates": ["maclab", "192.168.1.52"],
        "tailscale_names": ["maclab"],
        "tailscale_fallbacks": [],
        "wake_mac": "14:7d:da:ce:bb:9c",
        "wake_broadcast": "192.168.1.255",
        "wake_port": "9",
    },
}

SSH_PROBE_OPTS = [
    "-o",
    "BatchMode=yes",
    "-o",
    "ConnectTimeout=3",
    "-o",
    "ServerAliveInterval=2",
    "-o",
    "ServerAliveCountMax=1",
]

# LAN reachability to these hosts is occasionally flaky (a single ssh attempt
# times out even though the host is up and a retry succeeds instantly), so
# each target gets a couple of tries before we give up on it.
SSH_PROBE_ATTEMPTS = 2
SSH_PROBE_RETRY_DELAY_SECONDS = 1.0


@dataclass(frozen=True)
class CommandSpec:
    argv: list[str]
    tty: bool = False
    remote_script: str | None = None


def normalize_hostname(hostname: str) -> str:
    return hostname.strip().lower().split(".", 1)[0]


def server_config(server_name: str) -> dict[str, list[str] | str]:
    try:
        return SERVERS[server_name]
    except KeyError as exc:
        known = ", ".join(sorted(SERVERS))
        raise SystemExit(f"Unknown homelab server '{server_name}'. Known: {known}") from exc


def _list_config_value(config: dict[str, list[str] | str], key: str) -> list[str]:
    value = config.get(key, [])
    if isinstance(value, str):
        return [value]
    return list(value)


def _string_config_value(config: dict[str, list[str] | str], key: str) -> str:
    value = config.get(key, "")
    if isinstance(value, str):
        return value
    raise SystemExit(f"Invalid server config: {key} must be a string")


def _int_config_value(config: dict[str, list[str] | str], key: str) -> int:
    value = _string_config_value(config, key)
    try:
        return int(value)
    except ValueError as exc:
        raise SystemExit(f"Invalid server config: {key} must be an integer") from exc


def is_local_server(server_name: str, current_hostname: str | None = None) -> bool:
    config = server_config(server_name)
    hostname = normalize_hostname(current_hostname or socket.gethostname())
    return hostname in {
        normalize_hostname(candidate)
        for candidate in _list_config_value(config, "local_hostnames")
    }


def tailscale_ips_for_server(server_name: str, status: dict[str, Any]) -> list[str]:
    config = server_config(server_name)
    wanted = {
        normalize_hostname(name)
        for name in _list_config_value(config, "tailscale_names")
    }
    ips: list[str] = []
    peers = status.get("Peer") or {}
    if not isinstance(peers, dict):
        return ips

    for peer in peers.values():
        if not isinstance(peer, dict):
            continue
        names = {
            normalize_hostname(str(peer.get("HostName", ""))),
            normalize_hostname(str(peer.get("DNSName", ""))),
        }
        if not names.intersection(wanted):
            continue
        for ip in peer.get("TailscaleIPs", []):
            if isinstance(ip, str) and ":" not in ip and ip not in ips:
                ips.append(ip)

    return ips


def load_tailscale_status() -> dict[str, Any] | None:
    try:
        result = subprocess.run(
            ["tailscale", "status", "--json"],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (FileNotFoundError, subprocess.SubprocessError):
        return None

    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def remote_targets(
    server_name: str,
    tailscale_status: dict[str, Any] | None = None,
) -> list[str]:
    config = server_config(server_name)
    user = _string_config_value(config, "user")
    hosts = list(_list_config_value(config, "candidates"))
    if tailscale_status:
        hosts.extend(tailscale_ips_for_server(server_name, tailscale_status))
    hosts.extend(_list_config_value(config, "tailscale_fallbacks"))

    targets: list[str] = []
    for host in hosts:
        target = f"{user}@{host}"
        if target not in targets:
            targets.append(target)
    return targets


def build_command_spec(mode: str, argv: list[str]) -> CommandSpec:
    if not argv:
        raise SystemExit(f"Usage: homelab.py {mode} <server> -- <command...>")
    return CommandSpec(argv=list(argv), tty=(mode == "tui"))


def build_imessage_spec() -> CommandSpec:
    script = "\n".join(
        [
            "if ! pgrep -f 'imsg serve' >/dev/null; then",
            "  nohup imsg serve >/tmp/imsg-serve.log 2>&1 < /dev/null &",
            "fi",
            "exec itui",
        ]
    )
    return CommandSpec(argv=["bash", "-lc", script], tty=True, remote_script=script)


def mac_address_bytes(mac_address: str) -> bytes:
    normalized = re.sub(r"[-:]", "", mac_address)
    if not re.fullmatch(r"[0-9A-Fa-f]{12}", normalized):
        raise SystemExit(f"Invalid MAC address: {mac_address}")
    return bytes.fromhex(normalized)


def build_magic_packet(mac_address: str) -> bytes:
    mac = mac_address_bytes(mac_address)
    return b"\xff" * 6 + mac * 16


def send_wake_packet(server_name: str) -> int:
    config = server_config(server_name)
    mac_address = _string_config_value(config, "wake_mac")
    broadcast = _string_config_value(config, "wake_broadcast")
    port = _int_config_value(config, "wake_port")
    packet = build_magic_packet(mac_address)

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(packet, (broadcast, port))

    print(
        "Sent Wake-on-LAN packet for "
        f"{server_name} to {mac_address} via {broadcast}:{port}"
    )
    return 0


def ssh_probe(
    target: str,
    *,
    attempts: int = SSH_PROBE_ATTEMPTS,
    retry_delay: float = SSH_PROBE_RETRY_DELAY_SECONDS,
) -> bool:
    for attempt in range(attempts):
        result = subprocess.run(
            ["ssh", *SSH_PROBE_OPTS, target, "true"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode == 0:
            return True
        if attempt + 1 < attempts:
            time.sleep(retry_delay)
    return False


def resolve_remote_target(server_name: str) -> tuple[str, list[str]]:
    status = load_tailscale_status()
    targets = remote_targets(server_name, status)
    attempted: list[str] = []
    for target in targets:
        attempted.append(target)
        if ssh_probe(target):
            return target, attempted
    raise SystemExit(
        "Unable to reach homelab server "
        f"'{server_name}'. Attempted: {', '.join(attempted) or 'none'}"
    )


def run_local(spec: CommandSpec) -> int:
    return subprocess.run(spec.argv).returncode


def build_ssh_command(target: str, spec: CommandSpec) -> list[str]:
    remote_script = spec.remote_script or shlex.join(spec.argv)
    ssh_cmd = ["ssh"]
    if spec.tty:
        ssh_cmd.append("-t")
    ssh_cmd.extend([target, "bash", "-lc", shlex.quote(remote_script)])
    return ssh_cmd


def run_remote(target: str, spec: CommandSpec) -> int:
    return subprocess.run(build_ssh_command(target, spec)).returncode


def execute(server_name: str, spec: CommandSpec) -> int:
    if is_local_server(server_name):
        return run_local(spec)
    target, _attempted = resolve_remote_target(server_name)
    return run_remote(target, spec)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="homelab.py",
        description="Run homelab commands locally or over SSH.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    run_parser = subparsers.add_parser("run", help="Run a non-interactive command")
    run_parser.add_argument("server")
    run_parser.add_argument("remote_args", nargs=argparse.REMAINDER)

    tui_parser = subparsers.add_parser("tui", help="Run an interactive TUI command")
    tui_parser.add_argument("server")
    tui_parser.add_argument("remote_args", nargs=argparse.REMAINDER)

    imessage_parser = subparsers.add_parser(
        "imessage",
        help="Ensure imsg serve is running, then launch itui",
    )
    imessage_parser.add_argument("server")

    wake_parser = subparsers.add_parser("wake", help="Send a Wake-on-LAN packet")
    wake_parser.add_argument("server")

    return parser.parse_args(argv)


def strip_command_separator(argv: list[str]) -> list[str]:
    if argv and argv[0] == "--":
        return argv[1:]
    return argv


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    if args.command in {"run", "tui"}:
        command_argv = strip_command_separator(args.remote_args)
        spec = build_command_spec(args.command, command_argv)
        return execute(args.server, spec)
    if args.command == "imessage":
        return execute(args.server, build_imessage_spec())
    if args.command == "wake":
        return send_wake_packet(args.server)
    raise SystemExit(f"Unsupported command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
