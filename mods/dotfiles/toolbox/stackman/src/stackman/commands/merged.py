from __future__ import annotations

from pathlib import Path

from ..context import AppContext
from ..git_ops import current_branch, merge_base, repo_db_key, repo_root
from ..store import (
    delete_branch,
    get_branch,
    initialize,
    list_branches_with_parent,
    upsert_branch,
)


def run(ctx: AppContext, *, branch: str | None, dry_run: bool) -> int:
    """Collapse stack metadata after a Git merge (see design doc: tracked vs untracked parent)."""
    initialize(ctx.db_path)

    worktree = repo_root(ctx.cwd)
    repo_key = repo_db_key(ctx.cwd)
    branch_name = branch or current_branch(worktree)
    subject = get_branch(ctx.db_path, repo_key, branch_name)
    if subject is None:
        raise SystemExit(
            f"Branch {branch_name!r} is not tracked in this repository; nothing to collapse."
        )

    parent_name = subject.parent_branch_name
    if parent_name is None:
        raise SystemExit(
            f"Branch {branch_name!r} has no recorded parent in stackman; "
            "it is not stacked under another branch."
        )

    parent_rec = get_branch(ctx.db_path, repo_key, parent_name)
    if parent_rec is None:
        return _run_merged_into_untracked_parent(
            ctx=ctx,
            worktree=worktree,
            repo_key=repo_key,
            merged_branch=branch_name,
            trunk_name=parent_name,
            dry_run=dry_run,
        )

    grandparent = parent_rec.parent_branch_name
    if grandparent is None:
        raise SystemExit(
            f"Parent branch {parent_name!r} has no recorded parent in stackman, so there is no "
            "grandparent to reparent onto. Run `stackman init --parent <trunk>` on "
            f"{parent_name!r} first, or if you merged this branch into an untracked trunk "
            f"(e.g. main), run `merged` from the branch that merged into that trunk instead."
        )

    dependents = list_branches_with_parent(ctx.db_path, repo_key, parent_name)
    if not dependents:
        raise SystemExit(
            f"No tracked branches record {parent_name!r} as parent (unexpected empty set)."
        )

    if dry_run:
        _emit(
            ctx,
            f"[stackman] Dry run: would remove tracked branch {parent_name!r} and reparent "
            f"{len(dependents)} branch(es) onto {grandparent!r}:",
        )
        for row in dependents:
            _emit(ctx, f"  - {row.branch_name}: parent {parent_name!r} → {grandparent!r}")
        _emit(ctx, "[stackman] Dry run complete (no database changes).")
        return 0

    for row in dependents:
        fork = merge_base(worktree, row.branch_name, grandparent)
        upsert_branch(
            ctx.db_path,
            repo_root=repo_key,
            branch_name=row.branch_name,
            parent_branch_name=grandparent,
            fork_point_sha=fork,
        )

    if not delete_branch(ctx.db_path, repo_key, parent_name):
        raise SystemExit(
            f"Failed to remove parent branch {parent_name!r} from the database after reparenting."
        )

    names = ", ".join(sorted(row.branch_name for row in dependents))
    ctx.stdout.write(
        f"Collapsed parent {parent_name!r} into {grandparent!r}: reparented [{names}] "
        f"and removed {parent_name!r} from stackman tracking (Git branches unchanged).\n"
    )
    return 0


def _run_merged_into_untracked_parent(
    *,
    ctx: AppContext,
    worktree: Path,
    repo_key: str,
    merged_branch: str,
    trunk_name: str,
    dry_run: bool,
) -> int:
    """``merged_branch`` merged into ``trunk_name`` (not tracked); drop merged branch, lift children."""
    children = list_branches_with_parent(ctx.db_path, repo_key, merged_branch)
    if dry_run:
        _emit(
            ctx,
            f"[stackman] Dry run: treat {merged_branch!r} as merged into untracked {trunk_name!r}; "
            f"would remove {merged_branch!r} from stackman and reparent {len(children)} branch(es) "
            f"onto {trunk_name!r}:",
        )
        for row in children:
            _emit(ctx, f"  - {row.branch_name}: parent {merged_branch!r} → {trunk_name!r}")
        if not children:
            _emit(ctx, f"  (no branches stacked on {merged_branch!r})")
        _emit(ctx, "[stackman] Dry run complete (no database changes).")
        return 0

    for row in children:
        fork = merge_base(worktree, row.branch_name, trunk_name)
        upsert_branch(
            ctx.db_path,
            repo_root=repo_key,
            branch_name=row.branch_name,
            parent_branch_name=trunk_name,
            fork_point_sha=fork,
        )

    if not delete_branch(ctx.db_path, repo_key, merged_branch):
        raise SystemExit(
            f"Failed to remove branch {merged_branch!r} from the database after reparenting."
        )

    if children:
        names = ", ".join(sorted(row.branch_name for row in children))
        ctx.stdout.write(
            f"Recorded {merged_branch!r} as merged into {trunk_name!r}: reparented [{names}] "
            f"onto {trunk_name!r} and removed {merged_branch!r} from stackman (Git branches unchanged).\n"
        )
    else:
        ctx.stdout.write(
            f"Recorded {merged_branch!r} as merged into {trunk_name!r}: removed "
            f"{merged_branch!r} from stackman (Git branches unchanged).\n"
        )
    return 0


def _emit(ctx: AppContext, message: str) -> None:
    ctx.stdout.write(message)
    if not message.endswith("\n"):
        ctx.stdout.write("\n")
