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
    help=(
        "Stack label to attach (repeat for multiple). If omitted, labels are copied from "
        "the tracked parent when it has labels; otherwise a new sm_… id is minted."
    ),
)
@click.pass_obj
def init(app: StackmanApp, parent: str | None, stacks: tuple[str, ...]) -> None:
    """Register the current branch."""
    raise SystemExit(app.init(parent=parent, stacks=stacks))


@cli.command()
@click.option(
    "--branch",
    help="Branch that merged into its recorded parent (default: current branch).",
)
@click.option(
    "--dry-run",
    is_flag=True,
    help="Show reparenting plan without updating the database.",
)
@click.pass_obj
def merged_cmd(app: StackmanApp, branch: str | None, dry_run: bool) -> None:
    """Update metadata after a merge: collapse a tracked parent, or remove a branch merged into untracked trunk."""
    raise SystemExit(app.merged(branch=branch, dry_run=dry_run))


@cli.command()
@click.argument("stack_id", required=False)
@click.option(
    "--dry-run",
    is_flag=True,
    help="Show the resolved sync set and planned steps without modifying the repository.",
)
@click.option(
    "-v",
    "--verbose",
    is_flag=True,
    help="Print the exact git rebase command implied for each branch.",
)
@click.option(
    "--squash",
    is_flag=True,
    help="Squash 2+ commits after the stored fork-point into one commit before rebasing each branch.",
)
@click.pass_obj
def sync(app: StackmanApp, stack_id: str | None, dry_run: bool, verbose: bool, squash: bool) -> None:
    """Rebase tracked branches for STACK_ID (or infer it from the current branch's labels)."""
    raise SystemExit(app.sync(stack_id=stack_id, dry_run=dry_run, verbose=verbose, squash=squash))


@cli.command("stacks")
@click.pass_obj
def stacks_command(app: StackmanApp) -> None:
    """List stack labels and all tracked branches in the global stackman database."""
    raise SystemExit(app.list_stacks())


@cli.group()
def stack() -> None:
    """Inspect or change stack labels (does not delete Git branches)."""


@stack.command("branches")
@click.argument("stack_id")
@click.pass_obj
def stack_branches_cmd(app: StackmanApp, stack_id: str) -> None:
    """List all branches annotated with STACK_ID (any repository)."""
    raise SystemExit(app.stack_branches(stack_id))


@stack.command("unlabel")
@click.argument("stack_id")
@click.option(
    "--branch",
    help="Branch to remove from the stack (default: current branch in the --cwd repository).",
)
@click.pass_obj
def stack_unlabel_cmd(app: StackmanApp, stack_id: str, branch: str | None) -> None:
    """Remove STACK_ID from a branch in the current repository."""
    raise SystemExit(app.stack_unlabel(stack_id, branch=branch))


@stack.command("delete")
@click.argument("stack_id")
@click.option(
    "--yes",
    is_flag=True,
    help="Confirm deletion of this stack id and all label rows (required).",
)
@click.pass_obj
def stack_delete_cmd(app: StackmanApp, stack_id: str, yes: bool) -> None:
    """Delete STACK_ID from the database and drop every branch label for it."""
    if not yes:
        raise SystemExit(
            "Refusing to delete a stack without --yes. "
            "This removes only the stack id and label rows (tracked branch metadata is kept). "
            "Re-run with: stackman stack delete STACK_ID --yes"
        )
    raise SystemExit(app.stack_delete(stack_id))


def main(argv: list[str] | None = None) -> int:
    try:
        cli.main(args=argv, prog_name="stackman", standalone_mode=False)
    except SystemExit as exc:
        code = exc.code
        if isinstance(code, int):
            return code
        if code:
            click.echo(str(code), err=True)
        return 1
    return 0
