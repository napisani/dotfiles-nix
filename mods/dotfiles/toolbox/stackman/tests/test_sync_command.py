from __future__ import annotations

import io
from pathlib import Path

from stackman.app import StackmanApp
from stackman.git_ops import is_ancestor
from stackman.store import initialize, label_branch, upsert_branch


def test_sync_rebases_linear_stack_when_trunk_moves(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("feature", from_ref="main")
    git_repo.commit("feature work", filename="feature.txt", content="feature\n")

    fork = git_repo.merge_base("feature", "main")
    db_path = stackman_db_path
    initialize(db_path)
    upsert_branch(
        db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="feature",
        parent_branch_name="main",
        fork_point_sha=fork,
    )
    label_branch(db_path, git_repo.canonical_repo_key(), "feature", "stack-1")

    git_repo.checkout("main")
    git_repo.commit("main moves", filename="main.txt", content="main\n")

    stdout = io.StringIO()
    stderr = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout,
        stderr=stderr,
    )
    assert app.sync(stack_id="stack-1") == 0
    assert stderr.getvalue() == ""

    out = stdout.getvalue()
    assert "[stackman] Stack label: 'stack-1'" in out
    assert "feature" in out
    assert "Sync finished successfully" in out

    assert git_repo.current_branch() == "main"
    git_repo.checkout("feature")
    assert git_repo.is_ancestor(git_repo.rev_parse("main"), "HEAD")


def test_sync_propagates_to_descendant_without_label(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("branch_a", from_ref="main")
    git_repo.commit("a", filename="a.txt", content="a\n")
    git_repo.checkout_new("branch_b", from_ref="branch_a")
    git_repo.commit("b", filename="b.txt", content="b\n")

    db_path = stackman_db_path
    initialize(db_path)
    fp_a = git_repo.merge_base("branch_a", "main")
    upsert_branch(
        db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="branch_a",
        parent_branch_name="main",
        fork_point_sha=fp_a,
    )
    fp_b = git_repo.merge_base("branch_b", "branch_a")
    upsert_branch(
        db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="branch_b",
        parent_branch_name="branch_a",
        fork_point_sha=fp_b,
    )
    label_branch(db_path, git_repo.canonical_repo_key(), "branch_a", "stack-x")

    git_repo.checkout("main")
    git_repo.commit("move main", filename="m.txt", content="m\n")

    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
    )
    assert app.sync(stack_id="stack-x") == 0

    git_repo.checkout("branch_b")
    assert git_repo.is_ancestor(git_repo.rev_parse("main"), "HEAD")


def test_sync_implicit_stack_from_current_branch_labels(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("feature", from_ref="main")
    git_repo.commit("f", filename="f.txt", content="f\n")
    fork = git_repo.merge_base("feature", "main")
    db_path = stackman_db_path
    initialize(db_path)
    upsert_branch(
        db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="feature",
        parent_branch_name="main",
        fork_point_sha=fork,
    )
    label_branch(db_path, git_repo.canonical_repo_key(), "feature", "only-stack")

    git_repo.checkout("main")
    git_repo.commit("m", filename="m2.txt", content="m\n")

    git_repo.checkout("feature")
    stdout = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout,
        stderr=io.StringIO(),
    )
    assert app.sync(stack_id=None) == 0
    assert "Stack label: 'only-stack'" in stdout.getvalue()


def test_sync_runs_in_linked_worktree_when_branch_is_checked_out_there(
    git_repo,
    stackman_db_path,
    tmp_path: Path,
) -> None:
    git_repo.checkout_new("dead-code3", from_ref="main")
    git_repo.commit("feature work", filename="feat.txt", content="feat\n")
    fork = git_repo.merge_base("dead-code3", "main")
    db_path = stackman_db_path
    initialize(db_path)
    upsert_branch(
        db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="dead-code3",
        parent_branch_name="main",
        fork_point_sha=fork,
    )
    label_branch(db_path, git_repo.canonical_repo_key(), "dead-code3", "sm_wt_stack")

    git_repo.checkout("main")
    wt = tmp_path / "dead-code3-wt"
    git_repo._run("worktree", "add", str(wt), "dead-code3")

    git_repo.commit("main moves", filename="main2.txt", content="main2\n")

    stdout = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout,
        stderr=io.StringIO(),
    )
    assert app.sync(stack_id="sm_wt_stack") == 0

    out = stdout.getvalue()
    assert str(wt.resolve()) in out
    assert "dead-code3" in out

    assert git_repo.current_branch() == "main"
    main_tip = git_repo.rev_parse("main")
    assert is_ancestor(wt, main_tip, "HEAD")


def test_sync_succeeds_when_unrelated_worktree_is_dirty(
    git_repo,
    stackman_db_path,
    tmp_path: Path,
) -> None:
    git_repo.checkout_new("feature", from_ref="main")
    git_repo.commit("f", filename="f.txt", content="f\n")
    fork = git_repo.merge_base("feature", "main")
    db_path = stackman_db_path
    initialize(db_path)
    upsert_branch(
        db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="feature",
        parent_branch_name="main",
        fork_point_sha=fork,
    )
    label_branch(db_path, git_repo.canonical_repo_key(), "feature", "stack-only")

    git_repo.checkout("main")
    noise = tmp_path / "noise-wt"
    git_repo.add_worktree(noise, new_branch="noise")
    (noise / "dirty.txt").write_text("noise\n")

    git_repo.commit("move main", filename="m3.txt", content="m3\n")

    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
    )
    assert app.sync(stack_id="stack-only") == 0


def test_sync_fails_with_details_when_involved_worktree_dirty(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("feature", from_ref="main")
    git_repo.commit("f", filename="f.txt", content="f\n")
    fork = git_repo.merge_base("feature", "main")
    db_path = stackman_db_path
    initialize(db_path)
    upsert_branch(
        db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="feature",
        parent_branch_name="main",
        fork_point_sha=fork,
    )
    label_branch(db_path, git_repo.canonical_repo_key(), "feature", "stack-x2")

    git_repo.checkout("main")
    (git_repo.root / "untracked-dirty.txt").write_text("x\n")

    stderr = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=stderr,
    )
    assert app.sync(stack_id="stack-x2") != 0
    err = stderr.getvalue()
    assert "untracked-dirty.txt" in err or "??" in err
