from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from pathlib import Path

import click

from . import __version__
from .app import StackmanApp


def _default_db_path() -> Path:
    """DB location: $XDG_DATA_HOME/stackman/stackman.db, else ~/.local/share/…."""
    base = os.environ.get("XDG_DATA_HOME")
    root = Path(base).expanduser() if base else Path("~/.local/share").expanduser()
    return root / "stackman" / "stackman.db"


@dataclass(slots=True)
class CliConfig:
    """Top-level (group) option values; each command resolves its own app from these."""

    group_db_path: Path
    group_repo: Path | None

    def resolve(self, db_path: Path | None, repo_path: Path | None) -> StackmanApp:
        """Build an app, letting a subcommand-level --db-path/--repo override the group value."""
        return StackmanApp(
            db_path=db_path or self.group_db_path,
            cwd=repo_path or self.group_repo or Path.cwd(),
            stdin=sys.stdin,
            stdout=sys.stdout,
            stderr=sys.stderr,
        )


def _completion_paths(ctx: click.Context) -> tuple[Path, Path]:
    """Best-effort (db_path, cwd) during shell completion, reading group + command params."""
    params = dict(ctx.params)
    parent_params = dict(ctx.parent.params) if ctx.parent else {}
    db_path = params.get("db_path") or parent_params.get("db_path") or _default_db_path()
    repo = params.get("repo_path") or parent_params.get("repo_path")
    return Path(db_path), (Path(repo) if repo else Path.cwd())


def _complete_tracked_branches(ctx: click.Context, param, incomplete: str) -> list[str]:
    """Complete from Stackman-tracked branch names. Must never raise (would break the shell)."""
    try:
        from .git_ops import repo_db_key
        from .store import list_branches

        db_path, cwd = _completion_paths(ctx)
        if not db_path.exists():  # don't create the db as a completion side effect
            return []
        names = [row.branch_name for row in list_branches(db_path, repo_db_key(cwd))]
    except Exception:
        return []
    return [name for name in names if name.startswith(incomplete)]


def _complete_local_branches(ctx: click.Context, param, incomplete: str) -> list[str]:
    """Complete from all local Git branches (for tracking new branches/parents)."""
    try:
        from .git_ops import local_branches

        _, cwd = _completion_paths(ctx)
        names = local_branches(cwd)
    except Exception:
        return []
    return [name for name in names if name.startswith(incomplete)]


def repo_options(func):
    """Attach --db-path/--repo to a subcommand so they work after the command name too.

    Subcommand-level values default to ``None`` and override the group-level ones only
    when explicitly supplied, so ``stackman --repo A list`` and ``stackman list --repo A``
    are equivalent.
    """
    func = click.option(
        "--repo",
        "repo_path",
        type=click.Path(path_type=Path),
        default=None,
        help="Repository working directory (any worktree). Overrides the top-level --repo.",
    )(func)
    func = click.option(
        "--db-path",
        type=click.Path(path_type=Path),
        default=None,
        help="Path to the SQLite database. Overrides the top-level --db-path.",
    )(func)
    return func


@click.group(invoke_without_command=True)
@click.version_option(__version__, "-V", "--version", prog_name="stackman")
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
    """Manage stacked Git branches.

    Stackman is branch-first: every command takes an optional BRANCH and can be
    run from any worktree of the repository. BRANCH defaults to the currently
    checked-out branch, so you rarely need to name it. Stackman only records
    parent/fork-point metadata in its own database — it never creates, deletes,
    or checks out Git branches.

    \b
    Removing tracking, two ways:
      done BRANCH     branch landed: drop it and reparent its children onto its parent
      forget BRANCH   just stop tracking this branch; children keep their old parent

    \b
    Examples:
      stackman track --parent main          # track the current branch onto main
      stackman chain main a b c             # record an existing linear stack
      stackman list                         # show the stack tree for this repo
      stackman sync feature                 # rebase the whole stack containing 'feature'
      stackman done feature                 # feature landed; lift its children up
      stackman forget --all                 # drop all tracking for this repo

    Every command is fully non-interactive; a TTY is never required. Add --json
    to `list`/`status` for machine-readable output.
    """
    ctx.obj = CliConfig(group_db_path=db_path, group_repo=repo_path)
    if ctx.invoked_subcommand is None:
        raise SystemExit(ctx.obj.resolve(None, None).status())


@cli.command()
@click.argument("branch", required=False, shell_complete=_complete_local_branches)
@click.option(
    "--parent",
    required=True,
    help="Parent branch this branch is stacked on.",
    shell_complete=_complete_local_branches,
)
@repo_options
@click.pass_obj
def track(cfg: CliConfig, branch: str | None, parent: str, db_path, repo_path) -> None:
    """Track BRANCH (default: current branch) as stacked on --parent."""
    app = cfg.resolve(db_path, repo_path)
    raise SystemExit(app.track(branch=branch, parent=parent))


@cli.command()
@click.argument("anchor", shell_complete=_complete_local_branches)
@click.argument("branches", nargs=-1, required=True, shell_complete=_complete_local_branches)
@repo_options
@click.pass_obj
def chain(cfg: CliConfig, anchor: str, branches: tuple[str, ...], db_path, repo_path) -> None:
    """Track an existing linear chain: ANCHOR BRANCH..."""
    app = cfg.resolve(db_path, repo_path)
    raise SystemExit(app.chain(anchor=anchor, branches=branches))


@cli.command("sync")
@click.argument("branch", required=False, shell_complete=_complete_tracked_branches)
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
@repo_options
@click.pass_obj
def sync_command(
    cfg: CliConfig,
    branch: str | None,
    dry_run: bool,
    verbose: bool,
    squash: bool,
    allow_dirty: bool,
    db_path,
    repo_path,
) -> None:
    """Sync the full stack containing BRANCH (default: current branch)."""
    app = cfg.resolve(db_path, repo_path)
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
@click.argument("branch", required=False, shell_complete=_complete_tracked_branches)
@click.option("--dry-run", is_flag=True, help="Show reparenting plan without updating the database.")
@repo_options
@click.pass_obj
def done_command(cfg: CliConfig, branch: str | None, dry_run: bool, db_path, repo_path) -> None:
    """Mark BRANCH as done and reparent its children onto its parent."""
    app = cfg.resolve(db_path, repo_path)
    raise SystemExit(app.done(branch=branch, dry_run=dry_run))


@cli.command()
@click.argument("branch", required=False, shell_complete=_complete_tracked_branches)
@click.option("--all", "forget_all", is_flag=True, help="Forget all tracked branches in this repo.")
@click.option(
    "--global",
    "is_global",
    is_flag=True,
    help="With --all, forget tracking across every repository in the database.",
)
@click.option("-y", "--yes", "assume_yes", is_flag=True, help="Skip the confirmation prompt for --all.")
@click.option(
    "--dry-run",
    is_flag=True,
    help="With --all, list what would be forgotten without changing anything.",
)
@repo_options
@click.pass_obj
def forget(
    cfg: CliConfig,
    branch: str | None,
    forget_all: bool,
    is_global: bool,
    assume_yes: bool,
    dry_run: bool,
    db_path,
    repo_path,
) -> None:
    """Stop tracking BRANCH without reparenting children.

    With --all, forget every tracked branch in the current repo (or all repos
    with --global). Git branches are never modified.
    """
    app = cfg.resolve(db_path, repo_path)
    if forget_all:
        if branch is not None:
            raise click.UsageError("Pass either a BRANCH or --all, not both.")
        raise SystemExit(
            app.forget_all(is_global=is_global, assume_yes=assume_yes, dry_run=dry_run)
        )
    if is_global:
        raise click.UsageError("--global only applies together with --all.")
    if dry_run:
        raise click.UsageError("--dry-run only applies together with --all.")
    raise SystemExit(app.forget(branch=branch))


@cli.command("status")
@click.argument("branch", required=False, shell_complete=_complete_tracked_branches)
@click.option("--json", "as_json", is_flag=True, help="Emit machine-readable JSON to stdout.")
@repo_options
@click.pass_obj
def status_command(cfg: CliConfig, branch: str | None, as_json: bool, db_path, repo_path) -> None:
    """Show tracking status for BRANCH (default: current branch)."""
    app = cfg.resolve(db_path, repo_path)
    raise SystemExit(app.status(branch=branch, as_json=as_json))


@cli.command("list")
@click.option("--json", "as_json", is_flag=True, help="Emit machine-readable JSON to stdout.")
@repo_options
@click.pass_obj
def list_command(cfg: CliConfig, as_json: bool, db_path, repo_path) -> None:
    """List tracked branches for the current repo as a stack tree."""
    app = cfg.resolve(db_path, repo_path)
    raise SystemExit(app.list(as_json=as_json))


@cli.command()
@click.argument("pr_number", type=int, required=True)
@click.option("--apply", "apply_changes", is_flag=True, help="Write the discovered tracking metadata.")
@repo_options
@click.pass_obj
def discover(cfg: CliConfig, pr_number: int, apply_changes: bool, db_path, repo_path) -> None:
    """Discover a stack by traversing open GitHub PR branches."""
    app = cfg.resolve(db_path, repo_path)
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
