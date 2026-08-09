from __future__ import annotations

import json
import subprocess
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from ..context import AppContext
from ..git_ops import branch_exists, repo_root
from .track import run_track

_GH_PR_FIELDS = "headRefName,baseRefName,number,title,url,state"


@dataclass(frozen=True)
class PullRequest:
    number: int
    head: str
    base: str
    title: str = ""
    url: str = ""
    state: str = ""

    @classmethod
    def from_gh(cls, raw: dict) -> "PullRequest":
        return cls(
            number=int(raw["number"]),
            head=str(raw["headRefName"]),
            base=str(raw["baseRefName"]),
            title=str(raw.get("title") or ""),
            url=str(raw.get("url") or ""),
            state=str(raw.get("state") or ""),
        )


@dataclass(frozen=True)
class DiscoverEdge:
    branch: str
    parent: str
    pr: PullRequest


@dataclass(frozen=True)
class DiscoverPlan:
    anchor: str
    selected: PullRequest
    edges: tuple[DiscoverEdge, ...]


def run(ctx: AppContext, *, pr_number: int, apply: bool) -> int:
    """Discover a stack from GitHub PR base/head relationships."""
    worktree = repo_root(ctx.cwd)
    selected = _gh_pr_view(worktree, pr_number)
    if selected.state and selected.state.upper() != "OPEN":
        raise SystemExit(
            f"PR #{selected.number} is {selected.state.lower()}; discover only imports open PR stacks."
        )

    open_prs = _gh_open_prs(worktree)
    if selected.number not in {pr.number for pr in open_prs}:
        open_prs.append(selected)

    plan = _build_plan(selected, open_prs)
    _print_plan(ctx, worktree, plan)

    if not apply:
        ctx.stdout.write("Run with --apply to update Stackman tracking.\n")
        return 0

    return _apply_plan(ctx, worktree, plan)


def _gh_pr_view(worktree: Path, pr_number: int) -> PullRequest:
    result = _run_gh(worktree, "pr", "view", str(pr_number), "--json", _GH_PR_FIELDS)
    return PullRequest.from_gh(_parse_json_object(result.stdout, f"gh pr view {pr_number}"))


def _gh_open_prs(worktree: Path) -> list[PullRequest]:
    result = _run_gh(
        worktree,
        "pr",
        "list",
        "--state",
        "open",
        "--limit",
        "1000",
        "--json",
        _GH_PR_FIELDS,
    )
    return [PullRequest.from_gh(raw) for raw in _parse_json_array(result.stdout, "gh pr list")]


def _run_gh(worktree: Path, *args: str) -> subprocess.CompletedProcess[str]:
    try:
        result = subprocess.run(
            ["gh", *args],
            cwd=worktree,
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise SystemExit("`gh` is required for `stackman discover`, but it was not found on PATH.") from exc

    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "").strip()
        message = f"`gh {' '.join(args)}` failed with exit {result.returncode}."
        if detail:
            message += f"\n{detail}"
        raise SystemExit(message)
    return result


def _parse_json_object(text: str, command: str) -> dict:
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{command} returned invalid JSON: {exc}") from exc
    if not isinstance(parsed, dict):
        raise SystemExit(f"{command} returned JSON {type(parsed).__name__}, expected object.")
    return parsed


def _parse_json_array(text: str, command: str) -> list[dict]:
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{command} returned invalid JSON: {exc}") from exc
    if not isinstance(parsed, list):
        raise SystemExit(f"{command} returned JSON {type(parsed).__name__}, expected array.")
    return parsed


def _build_plan(selected: PullRequest, prs: Iterable[PullRequest]) -> DiscoverPlan:
    by_head = _index_by_head(prs)
    upstream = _upstream_path(selected, by_head)
    anchor = upstream[0].base
    root = upstream[0]

    children_by_base: dict[str, list[PullRequest]] = defaultdict(list)
    for pr in by_head.values():
        children_by_base[pr.base].append(pr)
    for children in children_by_base.values():
        children.sort(key=lambda pr: (pr.head, pr.number))

    edges: list[DiscoverEdge] = []
    visited: set[str] = set()

    def visit(pr: PullRequest) -> None:
        if pr.head in visited:
            return
        visited.add(pr.head)
        edges.append(DiscoverEdge(branch=pr.head, parent=pr.base, pr=pr))
        for child in children_by_base.get(pr.head, []):
            visit(child)

    visit(root)
    return DiscoverPlan(anchor=anchor, selected=selected, edges=tuple(edges))


def _index_by_head(prs: Iterable[PullRequest]) -> dict[str, PullRequest]:
    by_head: dict[str, PullRequest] = {}
    for pr in prs:
        existing = by_head.get(pr.head)
        if existing is not None and existing.number != pr.number:
            raise SystemExit(
                f"Cannot discover stack: multiple open PRs use head branch {pr.head!r} "
                f"(#{existing.number}, #{pr.number})."
            )
        by_head[pr.head] = pr
    return by_head


def _upstream_path(selected: PullRequest, by_head: dict[str, PullRequest]) -> list[PullRequest]:
    path = [selected]
    seen = {selected.head}
    base = selected.base
    while base in by_head:
        parent = by_head[base]
        if parent.head in seen:
            raise SystemExit(f"Cannot discover stack: PR branch cycle at {parent.head!r}.")
        path.append(parent)
        seen.add(parent.head)
        base = parent.base
    path.reverse()
    return path


def _print_plan(ctx: AppContext, worktree: Path, plan: DiscoverPlan) -> None:
    ctx.stdout.write(f"Discovered PR stack from PR #{plan.selected.number} ({plan.selected.head}):\n")
    ctx.stdout.write(f"{plan.anchor}\n")
    for line in _tree_lines(plan.anchor, plan.edges):
        ctx.stdout.write(f"{line}\n")

    ctx.stdout.write("\nPlan:\n")
    for edge in plan.edges:
        suffix = _local_status_suffix(worktree, edge)
        ctx.stdout.write(f"  stackman track {edge.branch} --parent {edge.parent}{suffix}\n")


def _tree_lines(anchor: str, edges: tuple[DiscoverEdge, ...]) -> list[str]:
    children: dict[str, list[DiscoverEdge]] = defaultdict(list)
    for edge in edges:
        children[edge.parent].append(edge)
    for rows in children.values():
        rows.sort(key=lambda edge: (edge.branch, edge.pr.number))

    lines: list[str] = []

    def visit(parent: str, prefix: str = "") -> None:
        rows = children.get(parent, [])
        for index, edge in enumerate(rows):
            is_last = index == len(rows) - 1
            connector = "└── " if is_last else "├── "
            lines.append(f"{prefix}{connector}{edge.branch} (#{edge.pr.number})")
            next_prefix = prefix + ("    " if is_last else "│   ")
            visit(edge.branch, next_prefix)

    visit(anchor)
    return lines


def _local_status_suffix(worktree: Path, edge: DiscoverEdge) -> str:
    if not branch_exists(worktree, edge.branch):
        return "  # skipped by --apply: local branch missing"
    if not branch_exists(worktree, edge.parent):
        return "  # skipped by --apply: local parent missing"
    return ""


def _apply_plan(ctx: AppContext, worktree: Path, plan: DiscoverPlan) -> int:
    available_parents = {plan.anchor} if branch_exists(worktree, plan.anchor) else set()
    applied = 0
    skipped = 0

    ctx.stdout.write("\nApplying discovered tracking metadata:\n")
    for edge in plan.edges:
        reason = _skip_reason(worktree, edge, available_parents)
        if reason is not None:
            skipped += 1
            ctx.stdout.write(f"  skipped {edge.branch!r}: {reason}.\n")
            continue
        code = run_track(ctx, branch=edge.branch, parent=edge.parent)
        if code != 0:
            return code
        available_parents.add(edge.branch)
        applied += 1

    ctx.stdout.write(f"Discovery apply complete: tracked {applied}, skipped {skipped}.\n")
    return 0


def _skip_reason(worktree: Path, edge: DiscoverEdge, available_parents: set[str]) -> str | None:
    if not branch_exists(worktree, edge.branch):
        return "local branch missing"
    if not branch_exists(worktree, edge.parent):
        return "local parent missing"
    if edge.parent not in available_parents:
        return "parent was not imported"
    return None
