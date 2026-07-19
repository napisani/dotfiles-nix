"""Per-session Workmux status aggregation.

Workmux stores status in the @workmux_status tmux option on windows. A
session's display prefix is the unique, non-empty statuses across its
windows, joined in first-seen order (mirrors the bash `awk` logic in the
original tmux-session-picker.sh).

`build_state_map` fetches every window across every session in a single
`tmux list-windows -a` call rather than one call per session -- with dozens
of sessions, N sequential tmux calls is the dominant source of picker
startup latency.
"""

from tmux_picker import tmux


def build_state_map() -> dict[str, str]:
    statuses_by_session: dict[str, list[str]] = {}
    for session, status in tmux.list_windows_all():
        statuses_by_session.setdefault(session, []).append(status)

    state_map = {}
    for session, statuses in statuses_by_session.items():
        seen: list[str] = []
        for status in statuses:
            if status and status not in seen:
                seen.append(status)
        state_map[session] = " ".join(seen)
    return state_map


def format_session_lines(sessions: list[str]) -> list[str]:
    state_map = build_state_map()
    states = [state_map.get(session, "") for session in sessions]
    has_any_state = any(states)

    lines = []
    for session, state in zip(sessions, states):
        if has_any_state:
            prefix = f"{state} " if state else "   "
            lines.append(f"{prefix}{session}\t{session}")
        else:
            lines.append(f"{session}\t{session}")
    return lines
