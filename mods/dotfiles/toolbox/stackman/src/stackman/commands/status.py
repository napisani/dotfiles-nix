from __future__ import annotations

from ..context import AppContext
from ..git_ops import current_branch, format_repo_key_for_display, repo_db_key, repo_root
from ..store import get_branch, initialize, list_branch_labels


def run(ctx: AppContext) -> int:
    initialize(ctx.db_path)
    worktree = repo_root(ctx.cwd)
    repo_key = repo_db_key(ctx.cwd)
    branch_name = current_branch(worktree)
    tracked = get_branch(ctx.db_path, repo_key, branch_name)
    if tracked is None:
        ctx.stdout.write(
            f"Branch {branch_name!r} is not tracked in this Git repository "
            f"({format_repo_key_for_display(repo_key)}; worktree {worktree}).\n"
        )
        return 1

    labels = list_branch_labels(ctx.db_path, repo_key, branch_name)
    parent_display = tracked.parent_branch_name or "<none>"
    labels_display = ", ".join(labels) if labels else "<none>"
    ctx.stdout.write(f"branch: {tracked.branch_name}\n")
    ctx.stdout.write(f"worktree: {worktree}\n")
    ctx.stdout.write(f"parent: {parent_display}\n")
    ctx.stdout.write(f"fork-point: {tracked.fork_point_sha}\n")
    ctx.stdout.write(f"labels: {labels_display}\n")
    return 0
