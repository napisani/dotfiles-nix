"""Smart session removal, ported from tmux-session-kill.sh.

Branches:
  1. Popup session (_popup_*) -> kill directly.
  2. Workmux worktree session (nerd-font icon prefix) -> workmux remove
     --force, detached so the picker isn't blocked by the slow removal.
  3. Regular session -> kill its popup companion first, then the session.
"""

import subprocess
from pathlib import Path

from tmux_picker import tmux

# Nerd font icon used by Workmux as a session prefix (U+F418).
WORKMUX_PREFIX = ""


def _kill_if_exists(session: str) -> None:
    if tmux.has_session(session):
        tmux.kill_session(session)


def _git_common_dir(path: str) -> str | None:
    result = subprocess.run(
        ["git", "-C", path, "rev-parse", "--path-format=absolute", "--git-common-dir"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    common_dir = result.stdout.strip()
    if not common_dir:
        return None
    return common_dir.removesuffix("/.git")


def _has_workmux_config(main_repo: str) -> bool:
    return Path(main_repo, ".workmux.yaml").is_file()


def _spawn_workmux_remove(main_repo: str, branch: str, session: str) -> None:
    # Equivalent of the bash version's `nohup ... & disown`: detach so the
    # picker returns immediately while the slow `workmux remove --force`
    # runs in the background.
    subprocess.Popen(
        [
            "bash",
            "-c",
            'cd "$1" && workmux remove --force "$2" >/dev/null 2>&1\n'
            'tmux kill-session -t "=$3" >/dev/null 2>&1 || true',
            "_",
            main_repo,
            branch,
            session,
        ],
        start_new_session=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def kill(session: str) -> None:
    if session.startswith("_popup_"):
        _kill_if_exists(session)
        return

    if session.startswith(WORKMUX_PREFIX):
        branch = session[len(WORKMUX_PREFIX) :].lstrip()
        panes = tmux.list_panes(session)
        pane_path = panes[0] if panes else None

        if pane_path:
            main_repo = _git_common_dir(pane_path)
            if main_repo and _has_workmux_config(main_repo):
                _kill_if_exists(f"_popup_{session}_scratch")
                _spawn_workmux_remove(main_repo, branch, session)
                return

        # Fallback: worktree detection failed, kill popup + session directly.
        _kill_if_exists(f"_popup_{session}_scratch")
        _kill_if_exists(session)
        return

    # Regular session -> kill popup companion, then the session.
    _kill_if_exists(f"_popup_{session}_scratch")
    _kill_if_exists(session)
