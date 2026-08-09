"""Thin wrapper around the `tmux` binary.

Every shell-out to tmux lives here so the rest of the package (workmux
status aggregation, kill logic, CLI) never touches subprocess directly and
can be tested by faking these functions instead of a real tmux server.
"""

import subprocess


def list_sessions(filter_expr: str) -> list[tuple[str, str]]:
    """Every filtered session's (name, session_last_attached); the latter is
    an empty string for a session that has never been attached to."""
    result = subprocess.run(
        [
            "tmux",
            "list-sessions",
            "-f",
            filter_expr,
            "-F",
            "#S\t#{session_last_attached}",
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return []
    pairs = []
    for line in result.stdout.splitlines():
        name, _, last_attached = line.partition("\t")
        pairs.append((name, last_attached))
    return pairs


def list_windows_all() -> list[tuple[str, str]]:
    """Every window's (session_name, workmux_status), across every session,
    fetched in a single tmux call instead of one call per session."""
    result = subprocess.run(
        ["tmux", "list-windows", "-a", "-F", "#{session_name}\t#{@workmux_status}"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return []
    pairs = []
    for line in result.stdout.splitlines():
        session, _, status = line.partition("\t")
        pairs.append((session, status))
    return pairs


def list_panes(session: str) -> list[str]:
    result = subprocess.run(
        ["tmux", "list-panes", "-t", f"={session}", "-F", "#{pane_current_path}"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return []
    return result.stdout.splitlines()


def has_session(session: str) -> bool:
    result = subprocess.run(
        ["tmux", "has-session", "-t", f"={session}"],
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def kill_session(session: str) -> None:
    subprocess.run(["tmux", "kill-session", "-t", f"={session}"], capture_output=True)


def switch_client(session: str) -> None:
    subprocess.run(["tmux", "switch-client", "-t", session], capture_output=True)
