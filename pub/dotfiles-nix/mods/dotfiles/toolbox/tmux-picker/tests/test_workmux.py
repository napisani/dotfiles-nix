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


