from __future__ import annotations

import sqlite3

from ..models import BranchRecord, RepoRecord, StackRecord


def repo_from_row(row: sqlite3.Row | None) -> RepoRecord:
    if row is None:
        raise LookupError("Expected repo row")
    return RepoRecord(id=row["id"], root_path=row["root_path"], created_at=row["created_at"])


def branch_from_row(row: sqlite3.Row | None) -> BranchRecord:
    if row is None:
        raise LookupError("Expected branch row")
    return BranchRecord(
        id=row["id"],
        repo_id=row["repo_id"],
        repo_root=row["root_path"],
        branch_name=row["branch_name"],
        parent_branch_name=row["parent_branch_name"],
        fork_point_sha=row["fork_point_sha"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def stack_from_row(row: sqlite3.Row | None) -> StackRecord:
    if row is None:
        raise LookupError("Expected stack row")
    return StackRecord(id=row["id"], name=row["name"], created_at=row["created_at"])
