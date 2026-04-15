from __future__ import annotations

import io

from pathlib import Path

from stackman.app import StackmanApp
from stackman.store import initialize, label_branch, list_branch_labels, list_stack_summaries, upsert_branch


def test_list_stacks_and_branches_and_unlabel_and_delete(
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
    label_branch(db_path, git_repo.canonical_repo_key(), "feature", "stack-a")
    label_branch(db_path, git_repo.canonical_repo_key(), "feature", "stack-b")

    stdout = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout,
        stderr=io.StringIO(),
    )
    assert app.list_stacks() == 0
    out = stdout.getvalue()
    assert "Stack labels" in out
    assert "Tracked branches" in out
    assert "stack-a" in out and "stack-b" in out
    assert "feature" in out

    stdout2 = io.StringIO()
    app2 = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout2,
        stderr=io.StringIO(),
    )
    assert app2.stack_branches("stack-a") == 0
    assert "feature" in stdout2.getvalue()
    assert str(git_repo.root) in stdout2.getvalue()

    git_repo.checkout("feature")
    assert (
        StackmanApp(
            db_path=stackman_db_path,
            cwd=git_repo.root,
            stdin=io.StringIO(""),
            stdout=io.StringIO(),
            stderr=io.StringIO(),
        ).stack_unlabel("stack-a", branch=None)
        == 0
    )
    assert "stack-a" not in list_branch_labels(db_path, git_repo.canonical_repo_key(), "feature")
    assert "stack-b" in list_branch_labels(db_path, git_repo.canonical_repo_key(), "feature")

    assert (
        StackmanApp(
            db_path=stackman_db_path,
            cwd=git_repo.root,
            stdin=io.StringIO(""),
            stdout=io.StringIO(),
            stderr=io.StringIO(),
        ).stack_delete("stack-a")
        == 0
    )
    summaries = {s.stack_id for s in list_stack_summaries(db_path)}
    assert "stack-a" not in summaries
    assert "stack-b" in summaries


def test_stacks_shows_tracked_branches_without_stack_labels(
    git_repo,
    stackman_db_path,
) -> None:
    """`init` without `--stack` records lineage only; `stacks` must still show the repo."""
    git_repo.checkout_new("dead-code2", from_ref="main")
    git_repo.commit("dc2", filename="dc2.txt", content="dc2\n")
    fork = git_repo.merge_base("dead-code2", "main")

    db_path = stackman_db_path
    initialize(db_path)
    upsert_branch(
        db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="dead-code2",
        parent_branch_name="main",
        fork_point_sha=fork,
    )

    stdout = io.StringIO()
    assert (
        StackmanApp(
            db_path=stackman_db_path,
            cwd=git_repo.root,
            stdin=io.StringIO(""),
            stdout=stdout,
            stderr=io.StringIO(),
        ).list_stacks()
        == 0
    )
    out = stdout.getvalue()
    assert "Stack labels" in out
    assert "(none" in out
    assert "Tracked branches" in out
    assert "dead-code2" in out
    assert str(git_repo.root) in out


def test_stack_branches_unknown_id(tmp_path: Path) -> None:
    db_path = tmp_path / "s.db"
    initialize(db_path)
    app = StackmanApp(
        db_path=db_path,
        cwd=tmp_path,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
    )
    assert app.stack_branches("missing") == 1
