from __future__ import annotations

from ..context import AppContext
from ..git_ops import current_branch, format_repo_key_for_display, repo_db_key, repo_root
from ..store import (
    delete_stack,
    get_branch,
    initialize,
    list_global_tracked_branches,
    list_labeled_branches_for_stack,
    list_stack_summaries,
    remove_branch_stack_label,
)


def run_list_stacks(ctx: AppContext) -> int:
    initialize(ctx.db_path)
    summaries = list_stack_summaries(ctx.db_path)
    tracked = list_global_tracked_branches(ctx.db_path)

    if not summaries and not tracked:
        ctx.stdout.write(
            "Nothing in the stackman database yet (no stack labels and no tracked branches).\n"
        )
        return 0

    ctx.stdout.write(
        "Stack labels identify a slice for `stackman sync` and `stackman stack branches`. "
        "On `init`, use `--stack` for explicit ids; otherwise labels are inherited from a "
        "tracked parent when possible, else a new sm_… id is minted.\n"
        "Tracked lineage (parent and fork-point) is always stored and is listed below.\n\n"
    )

    ctx.stdout.write("Stack labels\n")
    if not summaries:
        ctx.stdout.write("  (none — no stack rows in the database yet)\n")
    else:
        ctx.stdout.write(f"  {'STACK ID':<34} {'REPOS':>6} {'BRANCHES':>9}\n")
        for row in summaries:
            name_suffix = f"  ({row.name})" if row.name else ""
            ctx.stdout.write(
                f"  {row.stack_id:<34} {row.repo_count:>6} {row.labeled_branch_count:>9}{name_suffix}\n"
            )

    ctx.stdout.write("\nTracked branches (all repositories)\n")
    if not tracked:
        ctx.stdout.write("  (none)\n")
        return 0

    current_repo: str | None = None
    for row in tracked:
        if row.repo_root != current_repo:
            current_repo = row.repo_root
            ctx.stdout.write(f"  {format_repo_key_for_display(row.repo_root)}\n")
        parent = row.parent_branch_name or "<none>"
        labels = ", ".join(row.stack_labels) if row.stack_labels else "<none>"
        ctx.stdout.write(
            f"    {row.branch_name:<32}  parent {parent:<24}  labels {labels}\n"
        )
    return 0


def run_stack_branches(ctx: AppContext, stack_id: str) -> int:
    initialize(ctx.db_path)
    known_ids = {s.stack_id for s in list_stack_summaries(ctx.db_path)}
    if stack_id not in known_ids:
        raise SystemExit(f"Unknown stack id {stack_id!r} (not present in the database).")
    rows = list_labeled_branches_for_stack(ctx.db_path, stack_id)
    if not rows:
        ctx.stdout.write(f"Stack {stack_id!r} has no labeled branches.\n")
        return 0
    ctx.stdout.write(f"Branches labeled {stack_id!r} ({len(rows)}):\n")
    for row in rows:
        parent = row.parent_branch_name or "<none>"
        ctx.stdout.write(
            f"  {row.branch_name}  (parent {parent})\n    {format_repo_key_for_display(row.repo_root)}\n"
        )
    return 0


def run_stack_unlabel(ctx: AppContext, stack_id: str, *, branch: str | None) -> int:
    initialize(ctx.db_path)
    known_ids = {s.stack_id for s in list_stack_summaries(ctx.db_path)}
    if stack_id not in known_ids:
        raise SystemExit(f"Unknown stack id {stack_id!r} (not present in the database).")

    worktree = repo_root(ctx.cwd)
    repo_key = repo_db_key(ctx.cwd)
    branch_name = branch or current_branch(worktree)
    removed = remove_branch_stack_label(
        ctx.db_path,
        repo_root=repo_key,
        branch_name=branch_name,
        stack_id=stack_id,
    )
    if not removed:
        tracked = get_branch(ctx.db_path, repo_key, branch_name)
        if tracked is None:
            raise SystemExit(
                f"Branch {branch_name!r} is not tracked in this repo; nothing to unlabel."
            )
        raise SystemExit(
            f"Branch {branch_name!r} does not carry stack label {stack_id!r}."
        )
    ctx.stdout.write(
        f"Removed stack label {stack_id!r} from branch {branch_name!r} "
        f"in worktree {worktree} ({format_repo_key_for_display(repo_key)}).\n"
    )
    return 0


def run_stack_delete(ctx: AppContext, stack_id: str) -> int:
    initialize(ctx.db_path)
    deleted = delete_stack(ctx.db_path, stack_id)
    if not deleted:
        raise SystemExit(f"Unknown stack id {stack_id!r} (not present in the database).")
    ctx.stdout.write(
        f"Deleted stack {stack_id!r} and all of its branch labels across repositories.\n"
        "Tracked branch metadata (parent / fork-point) was not removed.\n"
    )
    return 0
