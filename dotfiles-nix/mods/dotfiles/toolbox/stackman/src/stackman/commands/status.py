from __future__ import annotations

from ..context import AppContext
from ..git_ops import branch_exists, current_branch, format_repo_key_for_display, repo_db_key, repo_root
from ..store import get_branch, initialize


def run(ctx: AppContext, *, branch: str | None = None) -> int:
    initialize(ctx.db_path)
    worktree = repo_root(ctx.cwd)
    repo_key = repo_db_key(ctx.cwd)
    branch_name = branch or current_branch(worktree)
    if branch is not None and not branch_exists(worktree, branch_name):
        raise SystemExit(f"Branch {branch_name!r} does not exist in this Git repository.")

    tracked = get_branch(ctx.db_path, repo_key, branch_name)
    if tracked is None:
        ctx.stdout.write(
            f"Branch {branch_name!r} is not tracked in this Git repository "
            f"({format_repo_key_for_display(repo_key)}; worktree {worktree}).\n"
        )
        return 1

    parent_display = tracked.parent_branch_name or "<none>"
    ctx.stdout.write(f"branch: {tracked.branch_name}\n")
    ctx.stdout.write(f"worktree: {worktree}\n")
    ctx.stdout.write(f"parent: {parent_display}\n")
    ctx.stdout.write(f"fork-point: {tracked.fork_point_sha}\n")
    return 0
