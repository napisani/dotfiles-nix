from tmux_picker import kill


def test_kill_popup_session_kills_directly(monkeypatch):
    calls = []
    monkeypatch.setattr(kill.tmux, "has_session", lambda s: True)
    monkeypatch.setattr(kill.tmux, "kill_session", lambda s: calls.append(s))

    kill.kill("_popup_foo")

    assert calls == ["_popup_foo"]


def test_kill_popup_session_noop_when_missing(monkeypatch):
    calls = []
    monkeypatch.setattr(kill.tmux, "has_session", lambda s: False)
    monkeypatch.setattr(kill.tmux, "kill_session", lambda s: calls.append(s))

    kill.kill("_popup_foo")

    assert calls == []


def test_kill_workmux_session_removes_worktree(monkeypatch):
    session = f"{kill.WORKMUX_PREFIX} my-branch"
    killed = []
    spawned = {}

    monkeypatch.setattr(kill.tmux, "has_session", lambda s: True)
    monkeypatch.setattr(kill.tmux, "kill_session", lambda s: killed.append(s))
    monkeypatch.setattr(kill.tmux, "list_panes", lambda s: ["/repo/worktree"])
    monkeypatch.setattr(kill, "_git_common_dir", lambda path: "/repo/main")
    monkeypatch.setattr(kill, "_has_workmux_config", lambda main_repo: True)
    monkeypatch.setattr(
        kill,
        "_spawn_workmux_remove",
        lambda main_repo, branch, session: spawned.update(
            main_repo=main_repo, branch=branch, session=session
        ),
    )

    kill.kill(session)

    assert killed == [f"_popup_{session}_scratch"]
    assert spawned == {
        "main_repo": "/repo/main",
        "branch": "my-branch",
        "session": session,
    }


def test_kill_workmux_session_falls_back_when_worktree_detection_fails(monkeypatch):
    session = f"{kill.WORKMUX_PREFIX} my-branch"
    killed = []
    spawn_calls = []

    monkeypatch.setattr(kill.tmux, "has_session", lambda s: True)
    monkeypatch.setattr(kill.tmux, "kill_session", lambda s: killed.append(s))
    monkeypatch.setattr(kill.tmux, "list_panes", lambda s: ["/repo/worktree"])
    monkeypatch.setattr(kill, "_git_common_dir", lambda path: None)
    monkeypatch.setattr(
        kill,
        "_spawn_workmux_remove",
        lambda *a, **kw: spawn_calls.append((a, kw)),
    )

    kill.kill(session)

    assert killed == [f"_popup_{session}_scratch", session]
    assert spawn_calls == []


def test_kill_workmux_session_falls_back_when_no_panes(monkeypatch):
    session = f"{kill.WORKMUX_PREFIX} my-branch"
    killed = []

    monkeypatch.setattr(kill.tmux, "has_session", lambda s: True)
    monkeypatch.setattr(kill.tmux, "kill_session", lambda s: killed.append(s))
    monkeypatch.setattr(kill.tmux, "list_panes", lambda s: [])

    kill.kill(session)

    assert killed == [f"_popup_{session}_scratch", session]


def test_kill_regular_session_kills_popup_companion_then_session(monkeypatch):
    killed = []
    monkeypatch.setattr(kill.tmux, "has_session", lambda s: True)
    monkeypatch.setattr(kill.tmux, "kill_session", lambda s: killed.append(s))

    kill.kill("mysession")

    assert killed == ["_popup_mysession_scratch", "mysession"]
