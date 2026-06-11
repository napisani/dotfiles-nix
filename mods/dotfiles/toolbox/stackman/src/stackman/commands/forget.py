from __future__ import annotations

from ..context import AppContext
from ..git_ops import current_branch, repo_db_key, repo_root
from ..store import delete_branch, get_branch, initialize, list_branches_with_parent


def run(ctx: AppContext, *, branch: str | None) -> int:
    """Stop tracking a branch without changing child lineage."""
    initialize(ctx.db_path)

    worktree = repo_root(ctx.cwd)
    repo_key = repo_db_key(ctx.cwd)
    branch_name = branch or current_branch(worktree)
    tracked = get_branch(ctx.db_path, repo_key, branch_name)
    if tracked is None:
        raise SystemExit(f"Branch {branch_name!r} is not tracked in this repository.")

    children = list_branches_with_parent(ctx.db_path, repo_key, branch_name)
    if not delete_branch(ctx.db_path, repo_key, branch_name):
        raise SystemExit(f"Failed to remove branch {branch_name!r} from stackman tracking.")

    ctx.stdout.write(f"Forgot branch {branch_name!r} (Git branches unchanged).\n")
    if children:
        names = ", ".join(sorted(row.branch_name for row in children))
        ctx.stdout.write(
            f"Note: child branch(es) [{names}] still record {branch_name!r} as their parent. "
            f"Use `stackman done {branch_name}` instead when a merged branch should reparent its children.\n"
        )
    return 0
