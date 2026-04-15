from __future__ import annotations

from pathlib import Path

from ..models import BranchRecord
from .connection import connect, normalize_path
from .rows import branch_from_row
from .repos import upsert_repo


def upsert_branch(
    db_path: Path | str,
    *,
    repo_root: Path | str,
    branch_name: str,
    parent_branch_name: str | None,
    fork_point_sha: str,
) -> BranchRecord:
    repo = upsert_repo(db_path, repo_root)
    with connect(db_path) as conn:
        conn.execute(
            """
            INSERT INTO branches(repo_id, branch_name, parent_branch_name, fork_point_sha)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(repo_id, branch_name) DO UPDATE SET
                parent_branch_name = excluded.parent_branch_name,
                fork_point_sha = excluded.fork_point_sha,
                updated_at = CURRENT_TIMESTAMP
            """,
            (repo.id, branch_name, parent_branch_name, fork_point_sha),
        )
        row = conn.execute(
            """
            SELECT b.id, b.repo_id, r.root_path, b.branch_name,
                   b.parent_branch_name, b.fork_point_sha,
                   b.created_at, b.updated_at
            FROM branches AS b
            JOIN repos AS r ON r.id = b.repo_id
            WHERE r.root_path = ? AND b.branch_name = ?
            """,
            (repo.root_path, branch_name),
        ).fetchone()
    return branch_from_row(row)


def get_branch(db_path: Path | str, repo_root: Path | str, branch_name: str) -> BranchRecord | None:
    normalized = normalize_path(repo_root)
    with connect(db_path) as conn:
        row = conn.execute(
            """
            SELECT b.id, b.repo_id, r.root_path, b.branch_name,
                   b.parent_branch_name, b.fork_point_sha,
                   b.created_at, b.updated_at
            FROM branches AS b
            JOIN repos AS r ON r.id = b.repo_id
            WHERE r.root_path = ? AND b.branch_name = ?
            """,
            (normalized, branch_name),
        ).fetchone()
    return branch_from_row(row) if row else None


def list_branches(db_path: Path | str, repo_root: Path | str) -> list[BranchRecord]:
    normalized = normalize_path(repo_root)
    with connect(db_path) as conn:
        rows = conn.execute(
            """
            SELECT b.id, b.repo_id, r.root_path, b.branch_name,
                   b.parent_branch_name, b.fork_point_sha,
                   b.created_at, b.updated_at
            FROM branches AS b
            JOIN repos AS r ON r.id = b.repo_id
            WHERE r.root_path = ?
            ORDER BY b.branch_name
            """,
            (normalized,),
        ).fetchall()
    return [branch_from_row(row) for row in rows]


def list_branches_with_parent(
    db_path: Path | str, repo_root: Path | str, parent_branch_name: str
) -> list[BranchRecord]:
    normalized = normalize_path(repo_root)
    with connect(db_path) as conn:
        rows = conn.execute(
            """
            SELECT b.id, b.repo_id, r.root_path, b.branch_name,
                   b.parent_branch_name, b.fork_point_sha,
                   b.created_at, b.updated_at
            FROM branches AS b
            JOIN repos AS r ON r.id = b.repo_id
            WHERE r.root_path = ? AND b.parent_branch_name = ?
            ORDER BY b.branch_name
            """,
            (normalized, parent_branch_name),
        ).fetchall()
    return [branch_from_row(row) for row in rows]


def delete_branch(db_path: Path | str, repo_root: Path | str, branch_name: str) -> bool:
    branch = get_branch(db_path, repo_root, branch_name)
    if branch is None:
        return False
    with connect(db_path) as conn:
        conn.execute("DELETE FROM branches WHERE id = ?", (branch.id,))
    return True
