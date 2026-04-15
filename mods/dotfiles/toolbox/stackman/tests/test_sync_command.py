from __future__ import annotations

import io
from pathlib import Path
import subprocess

from stackman.app import StackmanApp
from stackman.git_ops import is_ancestor
from stackman.store import get_branch, initialize, label_branch, upsert_branch


class _ConflictResolverInput:
    def __init__(self, resolver) -> None:
        self._resolver = resolver
        self._calls = 0

    def readline(self) -> str:
        self._calls += 1
        self._resolver(self._calls)
        return "\n"


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


def test_sync_second_run_skips_branch_already_synced_to_parent_tip(
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
    main_tip = git_repo.rev_parse("main")

    first_stdout = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=first_stdout,
        stderr=io.StringIO(),
    )
    assert app.sync(stack_id="stack-1") == 0

    tracked = get_branch(stackman_db_path, git_repo.canonical_repo_key(), "feature")
    assert tracked is not None
    assert tracked.fork_point_sha == main_tip

    git_repo.checkout("feature")
    before = git_repo.rev_parse("HEAD")
    git_repo.checkout("main")

    second_stdout = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=second_stdout,
        stderr=io.StringIO(),
    )
    assert app.sync(stack_id="stack-1") == 0

    git_repo.checkout("feature")
    after = git_repo.rev_parse("HEAD")
    assert after == before
    assert "stored fork-point already matches current 'main' tip" in second_stdout.getvalue()


def test_sync_squash_collapses_multiple_post_fork_commits(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("feature", from_ref="main")
    git_repo.commit("first feature commit", filename="f1.txt", content="one\n")
    fork = git_repo.merge_base("feature", "main")
    git_repo.commit("second feature commit", filename="f2.txt", content="two\n")
    git_repo.commit("third feature commit", filename="f3.txt", content="three\n")

    db_path = stackman_db_path
    initialize(db_path)
    upsert_branch(
        db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="feature",
        parent_branch_name="main",
        fork_point_sha=fork,
    )
    label_branch(db_path, git_repo.canonical_repo_key(), "feature", "stack-squash")

    before_commits = git_repo.git("rev-list", "--count", f"{fork}..feature")
    assert before_commits == "3"

    stdout = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout,
        stderr=io.StringIO(),
    )
    assert app.sync(stack_id="stack-squash", squash=True) == 0

    after_commits = git_repo.git("rev-list", "--count", f"{fork}..feature")
    assert after_commits == "1"
    message = git_repo.git("log", "-1", "--format=%B", "feature").strip()
    assert message == "first feature commit"
    assert "collapsing 3 post-fork commits into one" in stdout.getvalue()


def test_sync_squash_leaves_single_post_fork_commit_unchanged(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("feature", from_ref="main")
    git_repo.commit("only feature commit", filename="f1.txt", content="one\n")
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
    label_branch(db_path, git_repo.canonical_repo_key(), "feature", "stack-one")

    before = git_repo.rev_parse("feature")
    stdout = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout,
        stderr=io.StringIO(),
    )
    assert app.sync(stack_id="stack-one", squash=True) == 0

    after = git_repo.rev_parse("feature")
    assert after == before
    assert "Squash skipped for 'feature' (1 post-fork commit)" in stdout.getvalue()


def test_sync_dry_run_reports_squash_plan(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("feature", from_ref="main")
    git_repo.commit("first feature commit", filename="f1.txt", content="one\n")
    fork = git_repo.merge_base("feature", "main")
    git_repo.commit("second feature commit", filename="f2.txt", content="two\n")

    db_path = stackman_db_path
    initialize(db_path)
    upsert_branch(
        db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="feature",
        parent_branch_name="main",
        fork_point_sha=fork,
    )
    label_branch(db_path, git_repo.canonical_repo_key(), "feature", "stack-dry-squash")

    before = git_repo.rev_parse("feature")
    stdout = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout,
        stderr=io.StringIO(),
    )
    assert app.sync(stack_id="stack-dry-squash", dry_run=True, squash=True) == 0

    after = git_repo.rev_parse("feature")
    assert after == before
    out = stdout.getvalue()
    assert "optional squash" in out
    assert "would collapse 2 post-fork commits into one before rebasing" in out


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


def test_sync_waits_for_rebase_continue_and_then_resumes(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.commit("base shared", filename="shared.txt", content="base\n")
    git_repo.checkout_new("feature", from_ref="main")
    git_repo.commit("feature edits shared", filename="shared.txt", content="feature\n")
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
    label_branch(db_path, git_repo.canonical_repo_key(), "feature", "stack-conflict")

    git_repo.checkout("main")
    git_repo.commit("main edits shared", filename="shared.txt", content="main\n")
    parent_tip = git_repo.rev_parse("main")

    def resolve_rebase(call_count: int) -> None:
        if call_count == 1:
            return
        (git_repo.root / "shared.txt").write_text("main\nfeature\n")
        git_repo.git("add", "shared.txt")
        subprocess.run(
            ["git", "-c", "core.editor=true", "rebase", "--continue"],
            cwd=git_repo.root,
            check=True,
            capture_output=True,
            text=True,
        )

    stdout = io.StringIO()
    stderr = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=_ConflictResolverInput(resolve_rebase),
        stdout=stdout,
        stderr=stderr,
    )
    assert app.sync(stack_id="stack-conflict") == 0
    err = stderr.getvalue()
    assert "Rebase failed on 'feature'" in err
    assert "was aborted" not in err

    tracked = get_branch(stackman_db_path, git_repo.canonical_repo_key(), "feature")
    assert tracked is not None
    assert tracked.fork_point_sha == parent_tip
    out = stdout.getvalue()
    assert "press Enter to resume" in out
    assert "still in progress" in out
    assert "completed; resuming sync" in out


def test_sync_exits_non_zero_when_conflicted_rebase_is_aborted(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.commit("base shared", filename="shared.txt", content="base\n")
    git_repo.checkout_new("feature", from_ref="main")
    git_repo.commit("feature edits shared", filename="shared.txt", content="feature\n")
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
    label_branch(db_path, git_repo.canonical_repo_key(), "feature", "stack-abort")

    git_repo.checkout("main")
    git_repo.commit("main edits shared", filename="shared.txt", content="main\n")
    original_tip = git_repo.rev_parse("feature")
    original_fork = fork

    def abort_rebase(_call_count: int) -> None:
        subprocess.run(
            ["git", "rebase", "--abort"],
            cwd=git_repo.root,
            check=True,
            capture_output=True,
            text=True,
        )

    stdout = io.StringIO()
    stderr = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=_ConflictResolverInput(abort_rebase),
        stdout=stdout,
        stderr=stderr,
    )
    assert app.sync(stack_id="stack-abort") != 0

    tracked = get_branch(stackman_db_path, git_repo.canonical_repo_key(), "feature")
    assert tracked is not None
    assert tracked.fork_point_sha == original_fork
    assert git_repo.rev_parse("feature") == original_tip
    assert "press Enter to resume" in stdout.getvalue()
    assert "was aborted" in stderr.getvalue()
