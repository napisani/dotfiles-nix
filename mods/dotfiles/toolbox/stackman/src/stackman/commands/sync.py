from __future__ import annotations

from pathlib import Path

from ..context import AppContext
from ..git_ops import (
    checkout,
    current_branch,
    push_force_with_lease_current_branch,
    rebase_in_progress_any_linked,
    rebase_onto,
    repo_db_key,
    repo_root,
    rev_parse,
    sync_relevant_worktrees,
    upstream_branch,
    worktree_dirty_preview,
    worktree_path_for_branch,
)
from ..store import (
    get_branch,
    initialize,
    list_branch_labels,
    list_branch_names_with_stack_label,
    list_branches,
)
from ..sync_plan import SyncPlan, build_sync_plan


def run(ctx: AppContext, *, stack_id: str | None, dry_run: bool, verbose: bool) -> int:
    initialize(ctx.db_path)

    worktree = repo_root(ctx.cwd)
    repo_key = repo_db_key(ctx.cwd)

    original_branch = current_branch(worktree)
    all_branches = list_branches(ctx.db_path, repo_key)
    if not all_branches:
        raise SystemExit("No branches are tracked for this repository.")

    resolved_stack = _resolve_stack_id(
        ctx,
        repo_key,
        original_branch,
        stack_id,
    )
    labeled_names = list_branch_names_with_stack_label(ctx.db_path, repo_key, resolved_stack)
    plan = build_sync_plan(resolved_stack, all_branches, labeled_names)
    if not plan.sync_branches:
        raise SystemExit(
            f"Stack {resolved_stack!r} resolved to an empty sync set (nothing to update)."
        )

    if not dry_run:
        involved = sync_relevant_worktrees(worktree, plan.order)
        dirty_blocks: list[str] = []
        for path in involved:
            preview = worktree_dirty_preview(path)
            if preview is not None:
                dirty_blocks.append(f"  {path}\n{preview}")
        if dirty_blocks:
            raise SystemExit(
                "These worktrees used by this sync are dirty; commit or stash, "
                "or pass --dry-run to inspect the plan only.\n"
                + "\n".join(dirty_blocks)
                + "\n(Other linked worktrees do not need to be clean.)"
            )

    _print_plan(ctx, plan, worktree, dry_run=dry_run)

    if dry_run:
        _emit(ctx, "[stackman] Planned steps (each branch: checkout → rebase --onto parent tip → push)")
        for branch_name in plan.order:
            record = next(b for b in all_branches if b.branch_name == branch_name)
            parent = record.parent_branch_name or "<none>"
            wt_hint = ""
            holder = worktree_path_for_branch(worktree, branch_name)
            if holder is not None and holder != worktree:
                wt_hint = f" (checkout in {holder})"
            _emit(
                ctx,
                f"  - {branch_name}: rebase onto tip of {parent!r} "
                f"(stored fork-point {record.fork_point_sha[:7]}){wt_hint}",
            )
        _emit(ctx, "[stackman] Dry run complete.")
        return 0

    by_name = {b.branch_name: b for b in all_branches}
    try:
        for branch_name in plan.order:
            record = by_name[branch_name]
            parent_name = record.parent_branch_name
            if parent_name is None:
                _emit(ctx, f"[stackman] Skipping {branch_name!r} (no parent recorded).")
                continue
            branch_wt = worktree_path_for_branch(worktree, branch_name) or worktree
            if branch_wt != worktree:
                _emit(
                    ctx,
                    f"[stackman] → Using worktree {branch_wt} (branch {branch_name!r} is checked out there)",
                )
            else:
                _emit(ctx, f"[stackman] → Checking out {branch_name!r}")
            checkout(branch_wt, branch_name)
            parent_tip = rev_parse(branch_wt, parent_name)
            onto = parent_tip
            upstream = record.fork_point_sha
            if verbose:
                _emit(
                    ctx,
                    f"[stackman]   git rebase --onto {onto} {upstream} "
                    f"(replay commits after stored fork-point onto current {parent_name!r})",
                )
            _emit(
                ctx,
                f"[stackman]   Rebasing {branch_name!r} onto {parent_name!r} "
                f"at {onto[:7]} (fork-point {upstream[:7]})",
            )
            result = rebase_onto(branch_wt, onto=onto, upstream=upstream)
            if result.returncode != 0:
                err = (result.stderr or "").strip() or (result.stdout or "").strip()
                ctx.stderr.write(
                    f"[stackman] Rebase failed on {branch_name!r} (exit {result.returncode}).\n"
                )
                if err:
                    ctx.stderr.write(f"{err}\n")
                ctx.stderr.write(
                    "[stackman] Resolve conflicts, then `git rebase --continue` "
                    "or `git rebase --abort`. Original branch not restored while rebase is in progress.\n"
                )
                return 1

            remote_ref = upstream_branch(branch_wt, branch_name)
            if remote_ref is None:
                _emit(ctx, f"[stackman]   No upstream tracking branch for {branch_name!r}; skipping push.")
            else:
                _emit(
                    ctx,
                    f"[stackman]   Pushing {branch_name!r} with --force-with-lease "
                    f"(upstream {remote_ref})",
                )
                push_result = push_force_with_lease_current_branch(branch_wt)
                if push_result.returncode != 0:
                    msg = (push_result.stderr or "").strip() or (push_result.stdout or "").strip()
                    ctx.stderr.write(
                        f"[stackman] Push failed for {branch_name!r} (exit {push_result.returncode}).\n"
                    )
                    if msg:
                        ctx.stderr.write(f"{msg}\n")
                    return 1
    finally:
        if not rebase_in_progress_any_linked(worktree):
            if current_branch(worktree) != original_branch:
                _emit(ctx, f"[stackman] Restoring previous branch {original_branch!r}")
                checkout(worktree, original_branch)

    _emit(ctx, "[stackman] Sync finished successfully.")
    return 0


def _emit(ctx: AppContext, message: str) -> None:
    ctx.stdout.write(message)
    if not message.endswith("\n"):
        ctx.stdout.write("\n")


def _resolve_stack_id(
    ctx: AppContext,
    repo_key: str,
    branch_name: str,
    explicit: str | None,
) -> str:
    if explicit:
        names = list_branch_names_with_stack_label(ctx.db_path, repo_key, explicit)
        if not names:
            raise SystemExit(
                f"No tracked branches carry stack label {explicit!r} in this repository."
            )
        return explicit

    tracked = get_branch(ctx.db_path, repo_key, branch_name)
    if tracked is None:
        raise SystemExit(
            "Current branch is not tracked by stackman. "
            "Run `stackman init` from this branch or pass STACK_ID explicitly."
        )
    labels = list_branch_labels(ctx.db_path, repo_key, branch_name)
    if not labels:
        raise SystemExit(
            "Current branch has no stack labels (likely recorded before stackman auto-assigned ids). "
            "Re-run `stackman init --parent <parent>` on this branch, or pass STACK_ID explicitly."
        )
    if len(labels) > 1:
        joined = ", ".join(labels)
        raise SystemExit(
            f"Current branch has multiple stack labels ({joined}). "
            "Re-run with an explicit STACK_ID argument."
        )
    return labels[0]


def _print_plan(ctx: AppContext, plan: SyncPlan, worktree: Path, *, dry_run: bool) -> None:
    mode = "Dry run — no git changes" if dry_run else "Applying sync"
    _emit(ctx, f"[stackman] {mode} in worktree {worktree}")
    _emit(ctx, f"[stackman] Stack label: {plan.stack_id!r}")
    _emit(
        ctx,
        f"[stackman] Labeled branches: {', '.join(sorted(plan.labeled_branches)) or '<none>'}",
    )
    _emit(ctx, f"[stackman] Resolved roots: {', '.join(sorted(plan.roots)) or '<none>'}")
    _emit(
        ctx,
        f"[stackman] Sync set ({len(plan.sync_branches)}): "
        f"{', '.join(plan.order)}",
    )
