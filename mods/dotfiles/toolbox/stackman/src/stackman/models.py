from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class RepoRecord:
    id: int
    root_path: str
    created_at: str | None = None


@dataclass(frozen=True)
class BranchRecord:
    id: int
    repo_id: int
    repo_root: str
    branch_name: str
    parent_branch_name: str | None
    fork_point_sha: str
    created_at: str | None = None
    updated_at: str | None = None


@dataclass(frozen=True)
class StackRecord:
    id: str
    name: str | None = None
    created_at: str | None = None


@dataclass(frozen=True)
class StackSummaryRecord:
    """Aggregate view of a stack id in the global database."""

    stack_id: str
    name: str | None
    created_at: str | None
    labeled_branch_count: int
    repo_count: int


@dataclass(frozen=True)
class LabeledBranchRow:
    """One branch carrying a stack label."""

    repo_root: str
    branch_name: str
    parent_branch_name: str | None


@dataclass(frozen=True)
class GlobalTrackedBranchRow:
    """Tracked branch row for global listing (`stackman stacks`)."""

    repo_root: str
    branch_name: str
    parent_branch_name: str | None
    stack_labels: tuple[str, ...]
