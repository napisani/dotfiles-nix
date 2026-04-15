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
    ParentCandidate,
    branch_exists,
    candidate_parent_branches,
    current_branch,
    is_ancestor,
    local_branches,
    merge_base,
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


def test_candidate_parent_branches_include_overlapping_local_branches(
    git_repo: GitRepoFixture,
) -> None:
    git_repo.checkout_new("branch_a", from_ref="main")
    git_repo.commit("branch a commit", filename="a.txt", content="a\n")
    git_repo.checkout_new("branch_b", from_ref="branch_a")
    git_repo.commit("branch b commit", filename="b.txt", content="b\n")
    git_repo.checkout("main")
    git_repo.checkout_new("branch_c", from_ref="main")
    git_repo.commit("branch c commit", filename="c.txt", content="c\n")

    candidates = candidate_parent_branches(git_repo.root, current="branch_b")
    names = [candidate.branch_name for candidate in candidates]

    assert names == ["branch_a", "main", "branch_c"]
    assert all(candidate.merge_base_sha for candidate in candidates)
    assert merge_base(git_repo.root, "branch_a", "branch_b") == candidates[0].merge_base_sha
    assert candidates[1].is_trunk


def test_parent_candidate_likelihood_score_weights_behind_more_heavily() -> None:
    likely_parent = ParentCandidate("branch_a", "abc1234", ahead=0, behind=1)
    plausible_ancestor = ParentCandidate("main", "abc1234", ahead=0, behind=2, is_trunk=True)
    suspicious_sibling = ParentCandidate("branch_c", "abc1234", ahead=1, behind=2)

    assert likely_parent.likelihood_score == 5
    assert plausible_ancestor.likelihood_score == 10
    assert suspicious_sibling.likelihood_score == 11
    assert likely_parent.likelihood_score < plausible_ancestor.likelihood_score
    assert plausible_ancestor.likelihood_score < suspicious_sibling.likelihood_score


def test_candidate_parent_branches_limits_results_to_top_25(git_repo: GitRepoFixture) -> None:
    git_repo.checkout_new("parent", from_ref="main")
    git_repo.commit("parent commit", filename="parent.txt", content="parent\n")
    git_repo.checkout_new("current", from_ref="parent")
    git_repo.commit("current commit", filename="current.txt", content="current\n")

    git_repo.checkout("main")
    for index in range(30):
        branch_name = f"candidate_{index:02d}"
        git_repo.checkout_new(branch_name, from_ref="main")
        git_repo.commit(
            f"{branch_name} commit",
            filename=f"branches/{branch_name}.txt",
            content=f"{branch_name}\n",
        )
        git_repo.checkout("main")

    candidates = candidate_parent_branches(git_repo.root, current="current")

    assert len(candidates) == 25
    assert candidates[0].branch_name == "parent"
    assert candidates[0].likelihood_score == 5
    assert all(
        candidates[index].likelihood_score <= candidates[index + 1].likelihood_score
        for index in range(len(candidates) - 1)
    )
