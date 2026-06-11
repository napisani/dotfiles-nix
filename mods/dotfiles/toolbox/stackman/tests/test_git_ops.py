from __future__ import annotations

import sys
from pathlib import Path

TEST_DIR = Path(__file__).resolve().parent
SRC_DIR = TEST_DIR.parent / "src"
for path in (SRC_DIR, TEST_DIR):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from git_repo_fixture import GitRepoFixture
from stackman.git_ops import (
    branch_exists,
    current_branch,
    is_ancestor,
    local_branches,
    repo_db_key,
    repo_root,
    sync_relevant_worktrees,
    worktree_path_for_branch,
)


def test_repo_db_key_matches_across_linked_worktrees(git_repo: GitRepoFixture, tmp_path: Path) -> None:
    wt = tmp_path / "second-wt"
    git_repo.add_worktree(wt, new_branch="wt_branch")
    assert repo_db_key(git_repo.root) == repo_db_key(wt)


def test_worktree_path_for_branch_returns_holder_path(
    git_repo: GitRepoFixture,
    tmp_path: Path,
) -> None:
    git_repo.checkout_new("held_branch", from_ref="main")
    git_repo.commit("on held", filename="h.txt", content="h\n")
    git_repo.checkout("main")
    wt = tmp_path / "held-wt"
    git_repo._run("worktree", "add", str(wt), "held_branch")
    assert worktree_path_for_branch(git_repo.root, "held_branch") == wt.resolve()


def test_sync_relevant_worktrees_dedupes_root_and_holders(
    git_repo: GitRepoFixture,
    tmp_path: Path,
) -> None:
    git_repo.checkout_new("a", from_ref="main")
    git_repo.commit("a", filename="a.txt", content="a\n")
    git_repo.checkout_new("b", from_ref="a")
    git_repo.commit("b", filename="b.txt", content="b\n")
    git_repo.checkout("main")
    wt_a = tmp_path / "wt-a"
    wt_b = tmp_path / "wt-b"
    git_repo._run("worktree", "add", str(wt_a), "a")
    git_repo._run("worktree", "add", str(wt_b), "b")
    paths = sync_relevant_worktrees(git_repo.root, ("a", "b"))
    assert set(paths) == {git_repo.root.resolve(), wt_a.resolve(), wt_b.resolve()}


def test_git_ops_reports_basic_repo_state(git_repo: GitRepoFixture) -> None:
    assert repo_root(git_repo.root) == git_repo.root
    assert current_branch(git_repo.root) == "main"
    assert local_branches(git_repo.root) == ["main"]
    assert branch_exists(git_repo.root, "main")
    assert is_ancestor(git_repo.root, "main", "HEAD")
