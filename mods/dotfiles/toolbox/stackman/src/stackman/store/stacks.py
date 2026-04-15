from __future__ import annotations

from pathlib import Path

from ..models import GlobalTrackedBranchRow, LabeledBranchRow, StackRecord, StackSummaryRecord
from .branches import get_branch
from .connection import connect, normalize_path
from .rows import stack_from_row


def create_stack(db_path: Path | str, stack_id: str, name: str | None = None) -> StackRecord:
    with connect(db_path) as conn:
        conn.execute(
            "INSERT INTO stacks(id, name) VALUES (?, ?) "
            "ON CONFLICT(id) DO UPDATE SET name=COALESCE(excluded.name, name)",
            (stack_id, name),
        )
        row = conn.execute(
            "SELECT id, name, created_at FROM stacks WHERE id = ?",
            (stack_id,),
        ).fetchone()
    return stack_from_row(row)


def label_branch(db_path: Path | str, repo_root: Path | str, branch_name: str, stack_id: str) -> None:
    branch = get_branch(db_path, repo_root, branch_name)
    if branch is None:
        raise LookupError(f"Unknown branch {branch_name!r} in repo {repo_root!s}")
    create_stack(db_path, stack_id)
    with connect(db_path) as conn:
        conn.execute(
            """
            INSERT INTO branch_stack_labels(branch_id, stack_id)
            VALUES (?, ?)
            ON CONFLICT(branch_id, stack_id) DO NOTHING
            """,
            (branch.id, stack_id),
        )


def list_branch_labels(db_path: Path | str, repo_root: Path | str, branch_name: str) -> list[str]:
    branch = get_branch(db_path, repo_root, branch_name)
    if branch is None:
        return []
    with connect(db_path) as conn:
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


def list_branch_names_with_stack_label(
    db_path: Path | str, repo_root: Path | str, stack_id: str
) -> list[str]:
    normalized = normalize_path(repo_root)
    with connect(db_path) as conn:
        rows = conn.execute(
            """
            SELECT b.branch_name
            FROM branches AS b
            JOIN repos AS r ON r.id = b.repo_id
            JOIN branch_stack_labels AS l ON l.branch_id = b.id
            WHERE r.root_path = ? AND l.stack_id = ?
            ORDER BY b.branch_name
            """,
            (normalized, stack_id),
        ).fetchall()
    return [row[0] for row in rows]


def list_stack_summaries(db_path: Path | str) -> list[StackSummaryRecord]:
    with connect(db_path) as conn:
        rows = conn.execute(
            """
            SELECT
                s.id AS stack_id,
                s.name AS name,
                s.created_at AS created_at,
                COUNT(l.branch_id) AS labeled_branch_count,
                COUNT(DISTINCT b.repo_id) AS repo_count
            FROM stacks AS s
            LEFT JOIN branch_stack_labels AS l ON l.stack_id = s.id
            LEFT JOIN branches AS b ON b.id = l.branch_id
            GROUP BY s.id
            ORDER BY s.id
            """
        ).fetchall()
    return [
        StackSummaryRecord(
            stack_id=row["stack_id"],
            name=row["name"],
            created_at=row["created_at"],
            labeled_branch_count=int(row["labeled_branch_count"]),
            repo_count=int(row["repo_count"]),
        )
        for row in rows
    ]


def list_global_tracked_branches(db_path: Path | str) -> list[GlobalTrackedBranchRow]:
    """All tracked branches in the database with optional stack label ids."""
    with connect(db_path) as conn:
        rows = conn.execute(
            """
            SELECT r.root_path AS repo_root,
                   b.branch_name AS branch_name,
                   b.parent_branch_name AS parent_branch_name,
                   COALESCE(GROUP_CONCAT(l.stack_id, CHAR(31)), '') AS packed_labels
            FROM branches AS b
            JOIN repos AS r ON r.id = b.repo_id
            LEFT JOIN branch_stack_labels AS l ON l.branch_id = b.id
            GROUP BY b.id
            ORDER BY r.root_path, b.branch_name
            """
        ).fetchall()
    out: list[GlobalTrackedBranchRow] = []
    for row in rows:
        raw = row["packed_labels"] or ""
        labels = tuple(
            sorted({part for part in raw.split(chr(31)) if part}),
        )
        out.append(
            GlobalTrackedBranchRow(
                repo_root=row["repo_root"],
                branch_name=row["branch_name"],
                parent_branch_name=row["parent_branch_name"],
                stack_labels=labels,
            )
        )
    return out


def list_labeled_branches_for_stack(db_path: Path | str, stack_id: str) -> list[LabeledBranchRow]:
    with connect(db_path) as conn:
        rows = conn.execute(
            """
            SELECT r.root_path AS repo_root,
                   b.branch_name AS branch_name,
                   b.parent_branch_name AS parent_branch_name
            FROM branch_stack_labels AS l
            JOIN branches AS b ON b.id = l.branch_id
            JOIN repos AS r ON r.id = b.repo_id
            WHERE l.stack_id = ?
            ORDER BY r.root_path, b.branch_name
            """,
            (stack_id,),
        ).fetchall()
    return [
        LabeledBranchRow(
            repo_root=row["repo_root"],
            branch_name=row["branch_name"],
            parent_branch_name=row["parent_branch_name"],
        )
        for row in rows
    ]


def remove_branch_stack_label(
    db_path: Path | str,
    *,
    repo_root: Path | str,
    branch_name: str,
    stack_id: str,
) -> bool:
    branch = get_branch(db_path, repo_root, branch_name)
    if branch is None:
        return False
    with connect(db_path) as conn:
        cur = conn.execute(
            """
            DELETE FROM branch_stack_labels
            WHERE branch_id = ? AND stack_id = ?
            """,
            (branch.id, stack_id),
        )
        return cur.rowcount > 0


def delete_stack(db_path: Path | str, stack_id: str) -> bool:
    """Remove the stack row; CASCADE deletes all label rows for this stack id."""
    with connect(db_path) as conn:
        cur = conn.execute("DELETE FROM stacks WHERE id = ?", (stack_id,))
        return cur.rowcount > 0
