from __future__ import annotations

import sys
from pathlib import Path

import click

from .app import StackmanApp


def _default_db_path() -> Path:
    return Path("~/.local/share/stackman/stackman.db").expanduser()


def _build_app(db_path: Path, cwd: Path) -> StackmanApp:
    return StackmanApp(
        db_path=db_path,
        cwd=cwd,
        stdin=sys.stdin,
        stdout=sys.stdout,
        stderr=sys.stderr,
    )


@click.group()
@click.option(
    "--db-path",
    type=click.Path(path_type=Path),
    default=_default_db_path,
    show_default=True,
    help="Path to the SQLite database.",
)
@click.option(
    "--cwd",
    type=click.Path(path_type=Path),
    default=Path.cwd,
    show_default=True,
    help="Repository working directory.",
)
@click.pass_context
def cli(ctx: click.Context, db_path: Path, cwd: Path) -> None:
    """Manage stacked Git branches."""
    ctx.obj = _build_app(db_path, cwd)


@cli.command()
@click.pass_obj
def status(app: StackmanApp) -> None:
    """Show the current stack state."""
    raise SystemExit(app.status())


@cli.command()
@click.option(
    "--parent",
    help="Explicit parent branch. If omitted, stackman will prompt for confirmation.",
)
@click.option(
    "--stack",
    "stacks",
    multiple=True,
    help="Optional stack label to attach. May be passed multiple times.",
)
@click.pass_obj
def init(app: StackmanApp, parent: str | None, stacks: tuple[str, ...]) -> None:
    """Register the current branch."""
    raise SystemExit(app.init(parent=parent, stacks=stacks))


@cli.command()
def sync() -> None:
    """Sync a stack."""
    raise SystemExit(0)


def main(argv: list[str] | None = None) -> int:
    try:
        cli.main(args=argv, prog_name="stackman", standalone_mode=False)
    except SystemExit as exc:
        code = exc.code
        return code if isinstance(code, int) else 1
    return 0
