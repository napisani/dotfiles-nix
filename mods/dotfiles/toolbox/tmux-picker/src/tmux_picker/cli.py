"""argparse CLI: list/kill/pick subcommands for the tmux session picker.

Uses stdlib argparse instead of click to keep process-startup latency low --
this runs fresh on every keypress-driven popup open, so import cost matters.

`pick` is the entry point invoked from the tmux popup binding; `list` and
`kill` are also installed subcommands so fzf's own --bind execute/reload
actions can call back into this same tool instead of a temp-file hack.
"""

import argparse
import subprocess

from tmux_picker import kill
from tmux_picker import tmux
from tmux_picker import workmux

# Exclude _popup_* and _proctmux* sessions from the picker.
SESSION_FILTER = "#{?#{||:#{m:_popup_*,#S},#{m:_proctmux*,#S}},0,1}"


def _sort_by_recency(sessions: list[tuple[str, str]]) -> list[str]:
    """Most-recently-attached session first. Never-attached sessions (empty
    session_last_attached) form their own group at the bottom."""

    def key(entry: tuple[str, str]) -> tuple[int, int]:
        _, last_attached = entry
        if not last_attached:
            return (0, 0)
        return (1, int(last_attached))

    return [name for name, _ in sorted(sessions, key=key, reverse=True)]


def _cmd_list(args: argparse.Namespace) -> int:
    """Print <display>\t<raw_name> lines for all filtered sessions."""
    sessions = _sort_by_recency(tmux.list_sessions(SESSION_FILTER))
    for line in workmux.format_session_lines(sessions):
        print(line)
    return 0


def _cmd_kill(args: argparse.Namespace) -> int:
    """Kill a tmux session, using Workmux-aware smart removal."""
    kill.kill(args.session)
    return 0


def _cmd_pick(args: argparse.Namespace) -> int:
    """Launch the fzf session picker."""
    sessions = _sort_by_recency(tmux.list_sessions(SESSION_FILTER))
    lines = workmux.format_session_lines(sessions)
    input_text = "".join(f"{line}\n" for line in lines)

    subprocess.run(
        [
            "fzf",
            "--reverse",
            "--delimiter",
            "\t",
            "--with-nth=1",
            "--header",
            "Switch: enter | Kill: ctrl-x",
            "--bind",
            "enter:execute(tmux switch-client -t {2})+accept",
            "--bind",
            "ctrl-x:execute-silent(tmux-picker kill {2})+reload(tmux-picker list)",
        ],
        input=input_text,
        text=True,
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="tmux-picker", description="tmux session picker.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help=_cmd_list.__doc__)
    list_parser.set_defaults(func=_cmd_list)

    kill_parser = subparsers.add_parser("kill", help=_cmd_kill.__doc__)
    kill_parser.add_argument("session")
    kill_parser.set_defaults(func=_cmd_kill)

    pick_parser = subparsers.add_parser("pick", help=_cmd_pick.__doc__)
    pick_parser.set_defaults(func=_cmd_pick)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)
