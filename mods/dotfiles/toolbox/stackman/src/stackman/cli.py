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


@click.group(invoke_without_command=True)
@click.option(
    "--db-path",
    type=click.Path(path_type=Path),
    default=_default_db_path,
    show_default=True,
    help="Path to the SQLite database.",
)
@click.option(
    "--repo",
    "repo_path",
    type=click.Path(path_type=Path),
    help="Repository working directory (any worktree). Defaults to the current directory.",
)
@click.pass_context
def cli(ctx: click.Context, db_path: Path, repo_path: Path | None) -> None:
    """Manage stacked Git branches."""
    app = _build_app(db_path, repo_path or Path.cwd())
    ctx.obj = app
    if ctx.invoked_subcommand is None:
        raise SystemExit(app.status())


@cli.command()
@click.argument("branch", required=False)
@click.option("--parent", required=True, help="Parent branch this branch is stacked on.")
@click.pass_obj
def track(app: StackmanApp, branch: str | None, parent: str) -> None:
    """Track BRANCH (default: current branch) as stacked on --parent."""
    raise SystemExit(app.track(branch=branch, parent=parent))


@cli.command()
@click.argument("anchor")
@click.argument("branches", nargs=-1, required=True)
@click.pass_obj
def chain(app: StackmanApp, anchor: str, branches: tuple[str, ...]) -> None:
    """Track an existing linear chain: ANCHOR BRANCH..."""
    raise SystemExit(app.chain(anchor=anchor, branches=branches))


@cli.command("sync")
@click.argument("branch", required=False)
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
@click.option(
    "--allow-dirty",
    is_flag=True,
    help="Skip dirty-worktree preflight; Git may still abort checkout or rebase.",
)
@click.pass_obj
def sync_command(
    app: StackmanApp,
    branch: str | None,
    dry_run: bool,
    verbose: bool,
    squash: bool,
    allow_dirty: bool,
) -> None:
    """Sync the full stack containing BRANCH (default: current branch)."""
    raise SystemExit(
        app.sync(
            branch=branch,
            dry_run=dry_run,
            verbose=verbose,
            squash=squash,
            allow_dirty=allow_dirty,
        )
    )


@cli.command("done")
@click.argument("branch", required=False)
@click.option("--dry-run", is_flag=True, help="Show reparenting plan without updating the database.")
@click.pass_obj
def done_command(app: StackmanApp, branch: str | None, dry_run: bool) -> None:
    """Mark BRANCH as done and reparent its children onto its parent."""
    raise SystemExit(app.done(branch=branch, dry_run=dry_run))


@cli.command()
@click.argument("branch", required=False)
@click.pass_obj
def forget(app: StackmanApp, branch: str | None) -> None:
    """Stop tracking BRANCH without reparenting children."""
    raise SystemExit(app.forget(branch=branch))


@cli.command("list")
@click.pass_obj
def list_command(app: StackmanApp) -> None:
    """List tracked branches for the current repo."""
    raise SystemExit(app.list())


@cli.command()
@click.argument("pr_number", type=int, required=True)
@click.option("--apply", "apply_changes", is_flag=True, help="Write the discovered tracking metadata.")
@click.pass_obj
def discover(app: StackmanApp, pr_number: int, apply_changes: bool) -> None:
    """Discover a stack by traversing open GitHub PR branches."""
    raise SystemExit(app.discover(pr_number=pr_number, apply=apply_changes))


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
    except click.ClickException as exc:
        exc.show()
        return exc.exit_code
    return 0
