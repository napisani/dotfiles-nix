from __future__ import annotations

import sys
import types
from pathlib import Path

SRC_DIR = Path(__file__).resolve().parents[1] / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

if "stackman" not in sys.modules:
    package = types.ModuleType("stackman")
    package.__path__ = [str(SRC_DIR / "stackman")]
    sys.modules["stackman"] = package

from stackman.db import StackmanDb


def test_db_initializes_and_persists_branch_records(tmp_path: Path) -> None:
    db = StackmanDb(tmp_path / "stackman.db")
    db.initialize()

    repo_root = tmp_path / "repo"
    repo_root.mkdir()

    branch = db.upsert_branch(
        repo_root=repo_root,
        branch_name="feature",
        parent_branch_name="main",
        fork_point_sha="abc1234",
    )

    loaded = db.get_branch(repo_root, "feature")
    assert loaded == branch
    assert loaded is not None
    assert loaded.repo_root == str(repo_root.resolve())
    assert loaded.parent_branch_name == "main"
    assert loaded.fork_point_sha == "abc1234"


def test_db_supports_stack_labels(tmp_path: Path) -> None:
    db = StackmanDb(tmp_path / "stackman.db")
    db.initialize()

    repo_root = tmp_path / "repo"
    repo_root.mkdir()
    db.upsert_branch(
        repo_root=repo_root,
        branch_name="feature",
        parent_branch_name="main",
        fork_point_sha="abc1234",
    )

    db.label_branch(repo_root, "feature", "stack-1")
    db.label_branch(repo_root, "feature", "stack-2")
    db.label_branch(repo_root, "feature", "stack-1")

    assert db.list_branch_labels(repo_root, "feature") == ["stack-1", "stack-2"]


def test_db_list_branches_returns_normalized_records(tmp_path: Path) -> None:
    db = StackmanDb(tmp_path / "stackman.db")
    db.initialize()

    repo_root = tmp_path / "repo"
    repo_root.mkdir()
    db.upsert_branch(
        repo_root=repo_root,
        branch_name="b",
        parent_branch_name="a",
        fork_point_sha="deadbeef",
    )
    db.upsert_branch(
        repo_root=repo_root,
        branch_name="a",
        parent_branch_name="main",
        fork_point_sha="cafebabe",
    )

    branches = db.list_branches(repo_root)
    assert [branch.branch_name for branch in branches] == ["a", "b"]
    assert branches[0].repo_root == str(repo_root.resolve())
