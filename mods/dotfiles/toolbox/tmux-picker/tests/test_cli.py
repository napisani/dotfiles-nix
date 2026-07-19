import subprocess

import pytest

from tmux_picker import cli


def test_sort_by_recency_orders_most_recent_first():
    sessions = [("a", "100"), ("b", "300"), ("c", "200")]

    assert cli._sort_by_recency(sessions) == ["b", "c", "a"]


def test_sort_by_recency_puts_never_attached_at_bottom():
    sessions = [("a", ""), ("b", "100"), ("c", "")]

    result = cli._sort_by_recency(sessions)

    assert result[0] == "b"
    assert set(result[1:]) == {"a", "c"}


def test_sort_by_recency_mixed():
    sessions = [("never1", ""), ("recent", "500"), ("older", "100"), ("never2", "")]

    result = cli._sort_by_recency(sessions)

    assert result[:2] == ["recent", "older"]
    assert set(result[2:]) == {"never1", "never2"}


def test_list_command_prints_formatted_lines(monkeypatch, capsys):
    monkeypatch.setattr(
        cli.tmux, "list_sessions", lambda filter_expr: [("a", "100"), ("b", "200")]
    )
    monkeypatch.setattr(
        cli.workmux, "format_session_lines", lambda sessions: [f"{s}\t{s}" for s in sessions]
    )

    exit_code = cli.main(["list"])

    assert exit_code == 0
    # b (last_attached=200) sorts before a (last_attached=100)
    assert capsys.readouterr().out == "b\tb\na\ta\n"


def test_kill_command_invokes_kill(monkeypatch):
    calls = []
    monkeypatch.setattr(cli.kill, "kill", lambda session: calls.append(session))

    exit_code = cli.main(["kill", "mysession"])

    assert exit_code == 0
    assert calls == ["mysession"]


def test_pick_command_builds_expected_fzf_invocation(monkeypatch):
    monkeypatch.setattr(cli.tmux, "list_sessions", lambda filter_expr: [("a", "100")])
    monkeypatch.setattr(cli.workmux, "format_session_lines", lambda sessions: ["a\ta"])

    captured = {}

    def fake_run(argv, **kwargs):
        captured["argv"] = argv
        captured["kwargs"] = kwargs
        return subprocess.CompletedProcess(argv, 0)

    monkeypatch.setattr(cli.subprocess, "run", fake_run)

    exit_code = cli.main(["pick"])

    assert exit_code == 0
    argv = captured["argv"]
    assert argv[0] == "fzf"
    assert "--bind" in argv
    bind_values = [argv[i + 1] for i, a in enumerate(argv) if a == "--bind"]
    assert "enter:execute(tmux switch-client -t {2})+accept" in bind_values
    assert (
        "ctrl-x:execute-silent(tmux-picker kill {2})+reload(tmux-picker list)"
        in bind_values
    )
    assert captured["kwargs"]["input"] == "a\ta\n"


def test_no_subcommand_is_an_error():
    # argparse's standard behavior: a missing required subcommand exits the
    # process directly rather than returning an error code.
    with pytest.raises(SystemExit) as exc_info:
        cli.main([])

    assert exc_info.value.code != 0
