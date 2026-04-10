from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from .models import BranchRecord, RepoRecord, StackRecord


class StackmanDb:
    def __init__(self, db_path: Path | str) -> None:
        self.db_path = Path(db_path)

    def initialize(self) -> None:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as conn:
            conn.executescript(
                """
                PRAGMA foreign_keys = ON;

                CREATE TABLE IF NOT EXISTS repos (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    root_path TEXT NOT NULL UNIQUE,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );

                CREATE TABLE IF NOT EXISTS stacks (
                    id TEXT PRIMARY KEY,
                    name TEXT,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );

                CREATE TABLE IF NOT EXISTS branches (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    repo_id INTEGER NOT NULL REFERENCES repos(id) ON DELETE CASCADE,
                    branch_name TEXT NOT NULL,
                    parent_branch_name TEXT,
                    fork_point_sha TEXT NOT NULL,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(repo_id, branch_name)
                );

                CREATE TABLE IF NOT EXISTS branch_stack_labels (
                    branch_id INTEGER NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
                    stack_id TEXT NOT NULL REFERENCES stacks(id) ON DELETE CASCADE,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (branch_id, stack_id)
                );

                CREATE INDEX IF NOT EXISTS idx_branches_repo_parent
                    ON branches(repo_id, parent_branch_name);
                CREATE INDEX IF NOT EXISTS idx_branch_stack_labels_stack_id
                    ON branch_stack_labels(stack_id);
                CREATE INDEX IF NOT EXISTS idx_branches_repo_name
                    ON branches(repo_id, branch_name);
                """
            )

    def upsert_repo(self, root_path: Path | str) -> RepoRecord:
        normalized = self._normalize_path(root_path)
        with self._connect() as conn:
            conn.execute(
                "INSERT INTO repos(root_path) VALUES (?) "
                "ON CONFLICT(root_path) DO UPDATE SET root_path=excluded.root_path",
                (normalized,),
            )
            row = conn.execute(
                "SELECT id, root_path, created_at FROM repos WHERE root_path = ?",
                (normalized,),
            ).fetchone()
        return self._repo_from_row(row)

    def get_repo(self, root_path: Path | str) -> RepoRecord | None:
        normalized = self._normalize_path(root_path)
        with self._connect() as conn:
            row = conn.execute(
                "SELECT id, root_path, created_at FROM repos WHERE root_path = ?",
                (normalized,),
            ).fetchone()
        return self._repo_from_row(row) if row else None

    def upsert_branch(
        self,
        *,
        repo_root: Path | str,
        branch_name: str,
        parent_branch_name: str | None,
        fork_point_sha: str,
    ) -> BranchRecord:
        repo = self.upsert_repo(repo_root)
        with self._connect() as conn:
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
        return self._branch_from_row(row)

    def get_branch(self, repo_root: Path | str, branch_name: str) -> BranchRecord | None:
        normalized = self._normalize_path(repo_root)
        with self._connect() as conn:
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
        return self._branch_from_row(row) if row else None

    def list_branches(self, repo_root: Path | str) -> list[BranchRecord]:
        normalized = self._normalize_path(repo_root)
        with self._connect() as conn:
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
        return [self._branch_from_row(row) for row in rows]

    def create_stack(self, stack_id: str, name: str | None = None) -> StackRecord:
        with self._connect() as conn:
            conn.execute(
                "INSERT INTO stacks(id, name) VALUES (?, ?) "
                "ON CONFLICT(id) DO UPDATE SET name=COALESCE(excluded.name, name)",
                (stack_id, name),
            )
            row = conn.execute(
                "SELECT id, name, created_at FROM stacks WHERE id = ?",
                (stack_id,),
            ).fetchone()
        return self._stack_from_row(row)

    def label_branch(self, repo_root: Path | str, branch_name: str, stack_id: str) -> None:
        branch = self.get_branch(repo_root, branch_name)
        if branch is None:
            raise LookupError(f"Unknown branch {branch_name!r} in repo {repo_root!s}")
        self.create_stack(stack_id)
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO branch_stack_labels(branch_id, stack_id)
                VALUES (?, ?)
                ON CONFLICT(branch_id, stack_id) DO NOTHING
                """,
                (branch.id, stack_id),
            )

    def list_branch_labels(self, repo_root: Path | str, branch_name: str) -> list[str]:
        branch = self.get_branch(repo_root, branch_name)
        if branch is None:
            return []
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT stack_id
                FROM branch_stack_labels
                WHERE branch_id = ?
                ORDER BY stack_id
                """,
                (branch.id,),
            ).fetchall()
        return [row[0] for row in rows]

    @contextmanager
    def _connect(self) -> Iterator[sqlite3.Connection]:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("PRAGMA foreign_keys = ON")
            yield conn
            conn.commit()
        finally:
            conn.close()

    def _normalize_path(self, value: Path | str) -> str:
        return str(Path(value).expanduser().resolve())

    def _repo_from_row(self, row: sqlite3.Row | None) -> RepoRecord:
        if row is None:
            raise LookupError("Expected repo row")
        return RepoRecord(id=row["id"], root_path=row["root_path"], created_at=row["created_at"])

    def _branch_from_row(self, row: sqlite3.Row | None) -> BranchRecord:
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

    def _stack_from_row(self, row: sqlite3.Row | None) -> StackRecord:
        if row is None:
            raise LookupError("Expected stack row")
        return StackRecord(id=row["id"], name=row["name"], created_at=row["created_at"])
