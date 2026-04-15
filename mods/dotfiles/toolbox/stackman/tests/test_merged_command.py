from __future__ import annotations

import io

from stackman.app import StackmanApp
from stackman.store import get_branch, initialize, upsert_branch


def test_merged_reparents_all_siblings_and_removes_parent(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("mid", from_ref="main")
    git_repo.commit("mid", filename="mid.txt", content="mid\n")
    git_repo.checkout_new("tip_a", from_ref="mid")
    git_repo.commit("a", filename="a.txt", content="a\n")
    git_repo.checkout("mid")
    git_repo.checkout_new("tip_b", from_ref="mid")
    git_repo.commit("b", filename="b.txt", content="b\n")

    key = git_repo.canonical_repo_key()
    db_path = stackman_db_path
    initialize(db_path)
    fp_mid = git_repo.merge_base("mid", "main")
    upsert_branch(
        db_path,
        repo_root=key,
        branch_name="mid",
        parent_branch_name="main",
        fork_point_sha=fp_mid,
    )
    upsert_branch(
        db_path,
        repo_root=key,
        branch_name="tip_a",
        parent_branch_name="mid",
        fork_point_sha=git_repo.merge_base("tip_a", "mid"),
    )
    upsert_branch(
        db_path,
        repo_root=key,
        branch_name="tip_b",
        parent_branch_name="mid",
        fork_point_sha=git_repo.merge_base("tip_b", "mid"),
    )

    git_repo.checkout("tip_a")
    stdout = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout,
        stderr=io.StringIO(),
    )
    assert app.merged(branch=None, dry_run=False) == 0
    out = stdout.getvalue()
    assert "mid" in out and "main" in out

    assert get_branch(db_path, key, "mid") is None
    ta = get_branch(db_path, key, "tip_a")
    tb = get_branch(db_path, key, "tip_b")
    assert ta is not None and tb is not None
    assert ta.parent_branch_name == "main"
    assert tb.parent_branch_name == "main"


def test_merged_into_untracked_trunk_removes_branch_and_reparents_children(
    git_repo,
    stackman_db_path,
) -> None:
    """When the parent (e.g. main) is not tracked, ``merged`` drops the merged branch and lifts children."""
    git_repo.checkout_new("topic", from_ref="main")
    git_repo.commit("t", filename="t.txt", content="t\n")
    git_repo.checkout_new("on_topic", from_ref="topic")
    git_repo.commit("o", filename="o.txt", content="o\n")

    key = git_repo.canonical_repo_key()
    db_path = stackman_db_path
    initialize(db_path)
    upsert_branch(
        db_path,
        repo_root=key,
        branch_name="topic",
        parent_branch_name="main",
        fork_point_sha=git_repo.merge_base("topic", "main"),
    )
    upsert_branch(
        db_path,
        repo_root=key,
        branch_name="on_topic",
        parent_branch_name="topic",
        fork_point_sha=git_repo.merge_base("on_topic", "topic"),
    )

    git_repo.checkout("topic")
    assert (
        StackmanApp(
            db_path=stackman_db_path,
            cwd=git_repo.root,
            stdin=io.StringIO(""),
            stdout=io.StringIO(),
            stderr=io.StringIO(),
        ).merged(branch=None, dry_run=False)
        == 0
    )

    assert get_branch(db_path, key, "topic") is None
    child = get_branch(db_path, key, "on_topic")
    assert child is not None
    assert child.parent_branch_name == "main"


def test_merged_dry_run_does_not_mutate_db(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("p", from_ref="main")
    git_repo.commit("p", filename="p.txt", content="p\n")
    git_repo.checkout_new("c", from_ref="p")
    git_repo.commit("c", filename="c.txt", content="c\n")
    key = git_repo.canonical_repo_key()
    db_path = stackman_db_path
    initialize(db_path)
    upsert_branch(
        db_path,
        repo_root=key,
        branch_name="p",
        parent_branch_name="main",
        fork_point_sha=git_repo.merge_base("p", "main"),
    )
    upsert_branch(
        db_path,
        repo_root=key,
        branch_name="c",
        parent_branch_name="p",
        fork_point_sha=git_repo.merge_base("c", "p"),
    )

    git_repo.checkout("c")
    assert (
        StackmanApp(
            db_path=stackman_db_path,
            cwd=git_repo.root,
            stdin=io.StringIO(""),
            stdout=io.StringIO(),
            stderr=io.StringIO(),
        ).merged(branch=None, dry_run=True)
        == 0
    )
    assert get_branch(db_path, key, "p") is not None
    assert get_branch(db_path, key, "c").parent_branch_name == "p"
