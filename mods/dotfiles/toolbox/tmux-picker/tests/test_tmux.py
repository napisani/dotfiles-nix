import subprocess

import pytest

from tmux_picker import tmux


def _fake_run(returncode=0, stdout=""):
    def run(argv, **kwargs):
        return subprocess.CompletedProcess(argv, returncode, stdout=stdout, stderr="")

    return run


def test_list_sessions_builds_expected_argv_and_parses_pairs(monkeypatch):
    captured = {}

    def fake_run(argv, **kwargs):
        captured["argv"] = argv
        return subprocess.CompletedProcess(
            argv, 0, stdout="alpha\t1784420000\nbeta\t\n", stderr=""
        )

    monkeypatch.setattr(tmux.subprocess, "run", fake_run)

    result = tmux.list_sessions("#{some_filter}")

    assert captured["argv"] == [
        "tmux",
        "list-sessions",
        "-f",
        "#{some_filter}",
        "-F",
        "#S\t#{session_last_attached}",
    ]
    assert result == [("alpha", "1784420000"), ("beta", "")]


def test_list_sessions_returns_empty_on_nonzero_exit(monkeypatch):
    monkeypatch.setattr(tmux.subprocess, "run", _fake_run(returncode=1, stdout=""))

    assert tmux.list_sessions("#{filter}") == []


def test_has_session_true_and_false(monkeypatch):
    monkeypatch.setattr(tmux.subprocess, "run", _fake_run(returncode=0))
    assert tmux.has_session("mysession") is True

    monkeypatch.setattr(tmux.subprocess, "run", _fake_run(returncode=1))
    assert tmux.has_session("mysession") is False


def test_kill_session_builds_expected_argv(monkeypatch):
    captured = {}

    def fake_run(argv, **kwargs):
        captured["argv"] = argv
        return subprocess.CompletedProcess(argv, 0)

    monkeypatch.setattr(tmux.subprocess, "run", fake_run)

    tmux.kill_session("mysession")

    assert captured["argv"] == ["tmux", "kill-session", "-t", "=mysession"]


def test_switch_client_builds_expected_argv(monkeypatch):
    captured = {}

    def fake_run(argv, **kwargs):
        captured["argv"] = argv
        return subprocess.CompletedProcess(argv, 0)

    monkeypatch.setattr(tmux.subprocess, "run", fake_run)

    tmux.switch_client("mysession")

    assert captured["argv"] == ["tmux", "switch-client", "-t", "mysession"]


def test_list_windows_all_builds_expected_argv_and_parses_pairs(monkeypatch):
    captured = {}

    def fake_run(argv, **kwargs):
        captured["argv"] = argv
        return subprocess.CompletedProcess(
            argv, 0, stdout="alpha\t🤖\nalpha\t\nbeta\t💬\n", stderr=""
        )

    monkeypatch.setattr(tmux.subprocess, "run", fake_run)

    result = tmux.list_windows_all()

    assert captured["argv"] == [
        "tmux",
        "list-windows",
        "-a",
        "-F",
        "#{session_name}\t#{@workmux_status}",
    ]
    assert result == [("alpha", "🤖"), ("alpha", ""), ("beta", "💬")]


def test_list_windows_all_returns_empty_when_no_server(monkeypatch):
    monkeypatch.setattr(tmux.subprocess, "run", _fake_run(returncode=1, stdout=""))

    assert tmux.list_windows_all() == []


def test_list_panes_parses_lines(monkeypatch):
    monkeypatch.setattr(
        tmux.subprocess,
        "run",
        _fake_run(returncode=0, stdout="/some/path\n/other/path\n"),
    )

    assert tmux.list_panes("mysession") == ["/some/path", "/other/path"]


def test_list_panes_returns_empty_on_missing_session(monkeypatch):
    monkeypatch.setattr(tmux.subprocess, "run", _fake_run(returncode=1, stdout=""))

    assert tmux.list_panes("gone") == []
