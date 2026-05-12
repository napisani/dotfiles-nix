#!/usr/bin/env python3
"""
Tests for homelab.py

Run with:
    uv run --with pytest pytest mods/dotfiles/toolbox/tests/homelab_test.py -q
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).parent.parent / "homelab.py"


def load_module():
    assert SCRIPT.exists(), "homelab.py should exist"
    spec = importlib.util.spec_from_file_location("homelab", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules["homelab"] = module
    spec.loader.exec_module(module)
    return module


def test_server_registry_contains_initial_hosts() -> None:
    homelab = load_module()

    assert homelab.SERVERS["supermicro"]["user"] == "nick"
    assert homelab.SERVERS["supermicro"]["candidates"] == [
        "supermicro",
        "192.168.1.51",
    ]
    assert homelab.SERVERS["maclab"]["user"] == "nick"
    assert homelab.SERVERS["maclab"]["candidates"] == [
        "maclab",
        "192.168.1.52",
    ]
    assert homelab.SERVERS["maclab"]["wake_mac"] == "14:7d:da:ce:bb:9c"
    assert homelab.SERVERS["maclab"]["wake_broadcast"] == "192.168.1.255"


def test_local_hostname_match_bypasses_ssh() -> None:
    homelab = load_module()

    assert homelab.is_local_server("supermicro", current_hostname="supermicro")
    assert homelab.is_local_server("supermicro", current_hostname="supermicro.local")
    assert not homelab.is_local_server("supermicro", current_hostname="maclab")


def test_remote_candidates_try_hostname_before_lan_ip() -> None:
    homelab = load_module()

    assert homelab.remote_targets("supermicro")[:2] == [
        "nick@supermicro",
        "nick@192.168.1.51",
    ]
    assert homelab.remote_targets("maclab")[:2] == [
        "nick@maclab",
        "nick@192.168.1.52",
    ]


def test_tailscale_discovery_adds_matching_host_ip() -> None:
    homelab = load_module()
    status = {
        "Peer": {
            "node-a": {
                "HostName": "supermicro",
                "DNSName": "supermicro.tailnet.ts.net.",
                "TailscaleIPs": ["100.64.0.10", "fd7a:115c:a1e0::10"],
            },
            "node-b": {
                "HostName": "other",
                "DNSName": "other.tailnet.ts.net.",
                "TailscaleIPs": ["100.64.0.11"],
            },
        }
    }

    assert homelab.tailscale_ips_for_server("supermicro", status) == ["100.64.0.10"]
    assert homelab.remote_targets("supermicro", tailscale_status=status)[2] == (
        "nick@100.64.0.10"
    )


def test_tailscale_discovery_treats_null_peer_list_as_no_peers() -> None:
    homelab = load_module()
    status = {"Peer": None}

    assert homelab.tailscale_ips_for_server("supermicro", status) == []
    assert homelab.remote_targets("supermicro", tailscale_status=status) == [
        "nick@supermicro",
        "nick@192.168.1.51",
    ]


def test_kubectl_command_spec_forwards_args_without_tty() -> None:
    homelab = load_module()

    spec = homelab.build_command_spec("run", ["kubectl", "get", "pods", "-n", "home"])

    assert spec.argv == ["kubectl", "get", "pods", "-n", "home"]
    assert spec.tty is False


def test_k9s_command_spec_uses_tty() -> None:
    homelab = load_module()

    spec = homelab.build_command_spec("tui", ["k9s", "-n", "home"])

    assert spec.argv == ["k9s", "-n", "home"]
    assert spec.tty is True


def test_macimessage_spec_starts_server_with_nohup_then_runs_itui() -> None:
    homelab = load_module()

    spec = homelab.build_imessage_spec()

    assert spec.tty is True
    assert "pgrep -f 'imsg serve'" in spec.remote_script
    assert "nohup imsg serve >/tmp/imsg-serve.log 2>&1 < /dev/null &" in (
        spec.remote_script
    )
    assert "exec itui" in spec.remote_script


def test_magic_packet_repeats_maclab_wake_mac() -> None:
    homelab = load_module()

    packet = homelab.build_magic_packet("14:7d:da:ce:bb:9c")
    mac_bytes = bytes.fromhex("147ddacebb9c")

    assert len(packet) == 102
    assert packet[:6] == b"\xff" * 6
    assert packet[6:12] == mac_bytes
    assert packet[-6:] == mac_bytes


def test_invalid_magic_packet_mac_exits() -> None:
    homelab = load_module()

    with pytest.raises(SystemExit):
        homelab.build_magic_packet("not-a-mac")


def test_send_wake_packet_uses_configured_broadcast(monkeypatch) -> None:
    homelab = load_module()
    sockets = []

    class FakeSocket:
        def __init__(self, family, kind):
            self.family = family
            self.kind = kind
            self.options = []
            self.sent = []

        def __enter__(self):
            return self

        def __exit__(self, _exc_type, _exc_value, _traceback):
            return None

        def setsockopt(self, *args):
            self.options.append(args)

        def sendto(self, packet, target):
            self.sent.append((packet, target))
            return len(packet)

    def fake_socket(family, kind):
        sock = FakeSocket(family, kind)
        sockets.append(sock)
        return sock

    monkeypatch.setattr(homelab.socket, "socket", fake_socket)

    assert homelab.send_wake_packet("maclab") == 0
    assert sockets[0].family == homelab.socket.AF_INET
    assert sockets[0].kind == homelab.socket.SOCK_DGRAM
    assert sockets[0].options == [
        (homelab.socket.SOL_SOCKET, homelab.socket.SO_BROADCAST, 1)
    ]
    assert sockets[0].sent[0][1] == ("192.168.1.255", 9)


def test_ssh_command_quotes_remote_script_as_single_bash_lc_argument() -> None:
    homelab = load_module()
    spec = homelab.build_command_spec("run", ["kubectl", "get", "pods", "-n", "home"])

    assert homelab.build_ssh_command("nick@supermicro", spec) == [
        "ssh",
        "nick@supermicro",
        "bash",
        "-lc",
        "'kubectl get pods -n home'",
    ]
