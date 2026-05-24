from __future__ import annotations

from pathlib import Path
from typing import Sequence

from ..context import AppContext
from ..git_ops import (
    ParentCandidate,
    branch_exists,
    candidate_parent_branches,
    current_branch,
    merge_base,
    repo_db_key,
    repo_root,
)
from ..prompts import PromptUnavailableError, select_parent_branch
from ..stack_ids import new_auto_stack_id
from ..store import get_branch, initialize, label_branch, list_branch_labels, list_branches, upsert_branch


def run(
    ctx: AppContext,
    *,
    parent: str | None,
    stacks: Sequence[str],
    branches: str | None = None,
) -> int:
    initialize(ctx.db_path)

    worktree = repo_root(ctx.cwd)
    repo_key = repo_db_key(ctx.cwd)
    if branches is not None:
        if parent is not None:
            raise SystemExit("--branches already includes the parent chain; do not pass --parent.")
        return _run_branch_chain(
            ctx,
            worktree=worktree,
            repo_key=repo_key,
            branches_csv=branches,
            stacks=stacks,
        )

    branch_name = current_branch(worktree)
    parent_branch = parent or _confirm_parent_branch(
        ctx=ctx,
        worktree=worktree,
        repo_key=repo_key,
        branch_name=branch_name,
    )
    fork_point_sha = merge_base(worktree, branch_name, parent_branch)

    upsert_branch(
        ctx.db_path,
        repo_root=repo_key,
        branch_name=branch_name,
        parent_branch_name=parent_branch,
        fork_point_sha=fork_point_sha,
    )
    if stacks:
        effective_stack_ids = list(stacks)
        label_mode: str = "explicit"
    else:
        parent_tracked = get_branch(ctx.db_path, repo_key, parent_branch)
        parent_labels = (
            list_branch_labels(ctx.db_path, repo_key, parent_branch)
            if parent_tracked is not None
            else []
        )
        if parent_labels:
            effective_stack_ids = list(parent_labels)
            label_mode = "inherited"
        else:
            effective_stack_ids = [_new_stack_id(ctx)]
            label_mode = "new_auto"

    anchor_branch_name = None if label_mode == "inherited" else parent_branch
    for stack_id in effective_stack_ids:
        label_branch(
            ctx.db_path,
            repo_key,
            branch_name,
            stack_id,
            anchor_branch_name=anchor_branch_name,
        )

    ctx.stdout.write(
        f"Tracked branch {branch_name!r} with parent {parent_branch!r} at {fork_point_sha[:7]}.\n"
    )
    joined = ", ".join(effective_stack_ids)
    if label_mode == "explicit":
        ctx.stdout.write(f"Stack label(s): {joined}.\n")
    elif label_mode == "inherited":
        ctx.stdout.write(
            f"Stack label(s): {joined} (inherited from tracked parent {parent_branch!r}).\n"
        )
    else:
        ctx.stdout.write(
            f"Stack label(s): {joined} (auto-generated; use `init --stack <id>` to choose your own).\n"
        )
    return 0


def _run_branch_chain(
    ctx: AppContext,
    *,
    worktree: Path,
    repo_key: str,
    branches_csv: str,
    stacks: Sequence[str],
) -> int:
    chain = _parse_branch_chain(branches_csv)
    missing = [branch_name for branch_name in chain if not branch_exists(worktree, branch_name)]
    if missing:
        joined = ", ".join(repr(branch_name) for branch_name in missing)
        raise SystemExit(f"--branches contains unknown local branch(es): {joined}.")

    anchor_branch = chain[0]
    effective_stack_ids = list(stacks) if stacks else [_new_stack_id(ctx)]
    for parent_branch, branch_name in zip(chain, chain[1:]):
        fork_point_sha = merge_base(worktree, branch_name, parent_branch)
        upsert_branch(
            ctx.db_path,
            repo_root=repo_key,
            branch_name=branch_name,
            parent_branch_name=parent_branch,
            fork_point_sha=fork_point_sha,
        )
        for stack_id in effective_stack_ids:
            label_branch(
                ctx.db_path,
                repo_key,
                branch_name,
                stack_id,
                anchor_branch_name=anchor_branch,
            )

    rendered_chain = " -> ".join(repr(branch_name) for branch_name in chain)
    ctx.stdout.write(f"Tracked stack chain {rendered_chain}.\n")
    ctx.stdout.write(f"Stack label(s): {', '.join(effective_stack_ids)}.\n")
    return 0


def _parse_branch_chain(branches_csv: str) -> list[str]:
    chain = [part.strip() for part in branches_csv.split(",")]
    if any(not branch_name for branch_name in chain):
        raise SystemExit("--branches must be a comma-separated list without empty branch names.")
    if len(chain) < 2:
        raise SystemExit("--branches must include an anchor and at least one stack branch.")
    duplicates = sorted({branch_name for branch_name in chain if chain.count(branch_name) > 1})
    if duplicates:
        joined = ", ".join(repr(branch_name) for branch_name in duplicates)
        raise SystemExit(f"--branches must not repeat branch names: {joined}.")
    return chain


def _new_stack_id(ctx: AppContext) -> str:
    if ctx.stack_id_factory is not None:
        return ctx.stack_id_factory()
    return new_auto_stack_id()


def _confirm_parent_branch(
    *,
    ctx: AppContext,
    worktree: Path,
    repo_key: str,
    branch_name: str,
) -> str:
    candidates = candidate_parent_branches(worktree, current=branch_name)
    if not candidates:
        raise SystemExit("No plausible parent branches found. Re-run with --parent.")

    tracked_names = {
        branch.branch_name
        for branch in list_branches(ctx.db_path, repo_key)
    }
    decorated_candidates = [
        ParentCandidate(
            branch_name=candidate.branch_name,
            merge_base_sha=candidate.merge_base_sha,
            ahead=candidate.ahead,
            behind=candidate.behind,
            is_trunk=candidate.is_trunk,
            is_tracked=candidate.branch_name in tracked_names,
        )
        for candidate in candidates
    ]

    try:
        return select_parent_branch(
            decorated_candidates,
            current_branch=branch_name,
            is_tty=ctx.stdin.isatty(),
            chooser=ctx.parent_chooser,
        )
    except PromptUnavailableError as exc:
        raise SystemExit(str(exc)) from exc
