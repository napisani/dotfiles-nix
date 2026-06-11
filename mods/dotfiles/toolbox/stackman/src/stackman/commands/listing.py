from __future__ import annotations

from ..context import AppContext
from ..git_ops import format_repo_key_for_display, repo_db_key, repo_root
from ..store import initialize, list_branches


def run_repo_list(ctx: AppContext) -> int:
    """List Stackman-tracked branches for the current repository only."""
    initialize(ctx.db_path)

    worktree = repo_root(ctx.cwd)
    repo_key = repo_db_key(ctx.cwd)
    branches = list_branches(ctx.db_path, repo_key)

    ctx.stdout.write(f"Tracked branches in {format_repo_key_for_display(repo_key)}\n")
    ctx.stdout.write(f"Worktree: {worktree}\n")
    if not branches:
        ctx.stdout.write("  (none)\n")
        return 0

    for row in branches:
        parent = row.parent_branch_name or "<none>"
        ctx.stdout.write(f"  {row.branch_name:<32} parent {parent}\n")
    return 0
