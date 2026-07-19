from tmux_picker import workmux


def test_build_state_map_dedupes_and_joins_statuses(monkeypatch):
    monkeypatch.setattr(
        workmux.tmux,
        "list_windows_all",
        lambda: [
            ("alpha", "🤖"),
            ("alpha", "🤖"),
            ("alpha", "💬"),
            ("alpha", ""),
            ("beta", ""),
        ],
    )

    assert workmux.build_state_map() == {"alpha": "🤖 💬", "beta": ""}


def test_build_state_map_empty_when_no_windows(monkeypatch):
    monkeypatch.setattr(workmux.tmux, "list_windows_all", lambda: [])

    assert workmux.build_state_map() == {}


def test_format_session_lines_no_state_when_none_present(monkeypatch):
    monkeypatch.setattr(workmux, "build_state_map", lambda: {})

    lines = workmux.format_session_lines(["alpha", "beta"])

    assert lines == ["alpha\talpha", "beta\tbeta"]


def test_format_session_lines_prefixes_with_state_or_spaces(monkeypatch):
    monkeypatch.setattr(workmux, "build_state_map", lambda: {"alpha": "🤖"})

    lines = workmux.format_session_lines(["alpha", "beta"])

    assert lines == ["🤖 alpha\talpha", "   beta\tbeta"]


def test_format_session_lines_makes_a_single_tmux_call(monkeypatch):
    calls = []
    monkeypatch.setattr(
        workmux.tmux,
        "list_windows_all",
        lambda: calls.append(1) or [("alpha", "🤖")],
    )

    workmux.format_session_lines(["alpha", "beta", "gamma"])

    assert len(calls) == 1
