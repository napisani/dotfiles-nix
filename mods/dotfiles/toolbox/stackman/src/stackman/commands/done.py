from __future__ import annotations

from pathlib import Path

from ..context import AppContext
from ..git_ops import current_branch, merge_base, repo_db_key, repo_root
from ..store import delete_branch, get_branch, initialize, list_branches_with_parent, upsert_branch


def run(ctx: AppContext, *, branch: str | None, dry_run: bool = False) -> int:
    """Mark a tracked branch as done and lift its children onto its parent."""
    initialize(ctx.db_path)

    worktree = repo_root(ctx.cwd)
    repo_key = repo_db_key(ctx.cwd)
    branch_name = branch or current_branch(worktree)
    tracked = get_branch(ctx.db_path, repo_key, branch_name)
    if tracked is None:
        raise SystemExit(
            f"Branch {branch_name!r} is not tracked in this repository. "
            "Pass the branch that was merged, e.g. `stackman done feature-name`."
        )

    parent_name = tracked.parent_branch_name
    if parent_name is None:
        raise SystemExit(
            f"Branch {branch_name!r} has no recorded parent; use `stackman forget {branch_name}` "
            "if you only want to remove tracking."
        )

    return _drop_branch_and_reparent_children(
        ctx,
        worktree=worktree,
        repo_key=repo_key,
        branch_name=branch_name,
        parent_name=parent_name,
        dry_run=dry_run,
    )


def _drop_branch_and_reparent_children(
    ctx: AppContext,
    *,
    worktree: Path,
    repo_key: str,
    branch_name: str,
    parent_name: str,
    dry_run: bool,
) -> int:
    children = list_branches_with_parent(ctx.db_path, repo_key, branch_name)

    if dry_run:
        _emit(
            ctx,
            f"[stackman] Dry run: would mark {branch_name!r} done, remove it from tracking, "
            f"and reparent {len(children)} child branch(es) onto {parent_name!r}:",
        )
        for row in children:
            _emit(ctx, f"  - {row.branch_name}: parent {branch_name!r} → {parent_name!r}")
        if not children:
            _emit(ctx, f"  (no branches stacked on {branch_name!r})")
        _emit(ctx, "[stackman] Dry run complete (no database changes).")
        return 0

    for row in children:
        fork = merge_base(worktree, row.branch_name, parent_name)
        upsert_branch(
            ctx.db_path,
            repo_root=repo_key,
            branch_name=row.branch_name,
            parent_branch_name=parent_name,
            fork_point_sha=fork,
        )

    if not delete_branch(ctx.db_path, repo_key, branch_name):
        raise SystemExit(f"Failed to remove branch {branch_name!r} from stackman tracking.")

    if children:
        names = ", ".join(sorted(row.branch_name for row in children))
        ctx.stdout.write(
            f"Marked {branch_name!r} done: reparented [{names}] onto {parent_name!r} "
            "and removed it from stackman tracking (Git branches unchanged).\n"
        )
    else:
        ctx.stdout.write(
            f"Marked {branch_name!r} done: removed it from stackman tracking "
            "(Git branches unchanged).\n"
        )
    return 0


def _emit(ctx: AppContext, message: str) -> None:
    ctx.stdout.write(message)
    if not message.endswith("\n"):
        ctx.stdout.write("\n")
