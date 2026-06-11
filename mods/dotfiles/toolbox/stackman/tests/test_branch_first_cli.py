from __future__ import annotations

import io

from click.testing import CliRunner

from stackman.app import StackmanApp
from stackman.cli import cli
from stackman.store import get_branch, initialize, label_branch, upsert_branch


def test_track_command_registers_named_branch_without_checking_it_out(git_repo, stackman_db_path) -> None:
    git_repo.checkout_new("feature", from_ref="main")
    git_repo.commit("feature work", filename="feature.txt", content="feature\n")
    git_repo.checkout("main")

    result = CliRunner().invoke(
        cli,
        [
            "--db-path",
            str(stackman_db_path),
            "--repo",
            str(git_repo.root),
            "track",
            "feature",
            "--parent",
            "main",
        ],
    )

    assert result.exit_code == 0, result.output
    tracked = get_branch(stackman_db_path, git_repo.canonical_repo_key(), "feature")
    assert tracked is not None
    assert tracked.parent_branch_name == "main"
    assert git_repo.current_branch() == "main"


def test_default_command_shows_current_branch_status(git_repo, stackman_db_path) -> None:
    git_repo.checkout_new("feature", from_ref="main")
    git_repo.commit("feature work", filename="feature.txt", content="feature\n")
    assert (
        StackmanApp(
            db_path=stackman_db_path,
            cwd=git_repo.root,
            stdin=io.StringIO(""),
            stdout=io.StringIO(),
            stderr=io.StringIO(),
        ).track(parent="main")
        == 0
    )

    result = CliRunner().invoke(
        cli,
        ["--db-path", str(stackman_db_path), "--repo", str(git_repo.root)],
    )

    assert result.exit_code == 0, result.output
    assert "branch: feature" in result.output
    assert "parent: main" in result.output


def test_chain_command_registers_linear_stack(git_repo, stackman_db_path) -> None:
    git_repo.checkout_new("a", from_ref="main")
    git_repo.commit("a", filename="a.txt", content="a\n")
    git_repo.checkout_new("b", from_ref="a")
    git_repo.commit("b", filename="b.txt", content="b\n")
    git_repo.checkout("main")

    result = CliRunner().invoke(
        cli,
        [
            "--db-path",
            str(stackman_db_path),
            "--repo",
            str(git_repo.root),
            "chain",
            "main",
            "a",
            "b",
        ],
    )

    assert result.exit_code == 0, result.output
    a = get_branch(stackman_db_path, git_repo.canonical_repo_key(), "a")
    b = get_branch(stackman_db_path, git_repo.canonical_repo_key(), "b")
    assert a is not None and a.parent_branch_name == "main"
    assert b is not None and b.parent_branch_name == "a"


def test_sync_named_branch_from_main_syncs_full_stack(git_repo, stackman_db_path) -> None:
    git_repo.checkout_new("a", from_ref="main")
    git_repo.commit("a", filename="a.txt", content="a\n")
    git_repo.checkout_new("b", from_ref="a")
    git_repo.commit("b", filename="b.txt", content="b\n")

    initialize(stackman_db_path)
    repo_key = git_repo.canonical_repo_key()
    upsert_branch(
        stackman_db_path,
        repo_root=repo_key,
        branch_name="a",
        parent_branch_name="main",
        fork_point_sha=git_repo.merge_base("a", "main"),
    )
    upsert_branch(
        stackman_db_path,
        repo_root=repo_key,
        branch_name="b",
        parent_branch_name="a",
        fork_point_sha=git_repo.merge_base("b", "a"),
    )
    label_branch(stackman_db_path, repo_key, "a", "stack-chain", anchor_branch_name="main")
    label_branch(stackman_db_path, repo_key, "b", "stack-chain", anchor_branch_name="main")

    git_repo.checkout("main")
    git_repo.commit("main moves", filename="main.txt", content="main\n")
    main_tip = git_repo.rev_parse("main")

    stdout = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout,
        stderr=io.StringIO(),
    )

    assert app.sync(branch="b") == 0
    git_repo.checkout("a")
    assert git_repo.is_ancestor(main_tip, "HEAD")
    a_tip = git_repo.rev_parse("a")
    git_repo.checkout("b")
    assert git_repo.is_ancestor(a_tip, "HEAD")
    assert "Sync finished successfully" in stdout.getvalue()


def test_done_named_branch_from_main_reparents_children(git_repo, stackman_db_path) -> None:
    git_repo.checkout_new("topic", from_ref="main")
    git_repo.commit("topic", filename="topic.txt", content="topic\n")
    git_repo.checkout_new("child", from_ref="topic")
    git_repo.commit("child", filename="child.txt", content="child\n")
    git_repo.checkout("main")

    initialize(stackman_db_path)
    repo_key = git_repo.canonical_repo_key()
    upsert_branch(
        stackman_db_path,
        repo_root=repo_key,
        branch_name="topic",
        parent_branch_name="main",
        fork_point_sha=git_repo.merge_base("topic", "main"),
    )
    upsert_branch(
        stackman_db_path,
        repo_root=repo_key,
        branch_name="child",
        parent_branch_name="topic",
        fork_point_sha=git_repo.merge_base("child", "topic"),
    )

    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
    )

    assert app.done(branch="topic") == 0
    assert get_branch(stackman_db_path, repo_key, "topic") is None
    child = get_branch(stackman_db_path, repo_key, "child")
    assert child is not None
    assert child.parent_branch_name == "main"


def test_forget_named_branch_does_not_reparent_children(git_repo, stackman_db_path) -> None:
    git_repo.checkout_new("topic", from_ref="main")
    git_repo.commit("topic", filename="topic.txt", content="topic\n")
    git_repo.checkout_new("child", from_ref="topic")
    git_repo.commit("child", filename="child.txt", content="child\n")
    git_repo.checkout("main")

    initialize(stackman_db_path)
    repo_key = git_repo.canonical_repo_key()
    upsert_branch(
        stackman_db_path,
        repo_root=repo_key,
        branch_name="topic",
        parent_branch_name="main",
        fork_point_sha=git_repo.merge_base("topic", "main"),
    )
    upsert_branch(
        stackman_db_path,
        repo_root=repo_key,
        branch_name="child",
        parent_branch_name="topic",
        fork_point_sha=git_repo.merge_base("child", "topic"),
    )

    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
    )

    assert app.forget(branch="topic") == 0
    assert get_branch(stackman_db_path, repo_key, "topic") is None
    child = get_branch(stackman_db_path, repo_key, "child")
    assert child is not None
    assert child.parent_branch_name == "topic"


def test_list_command_is_repo_local_by_default(git_repo, stackman_db_path) -> None:
    git_repo.checkout_new("feature", from_ref="main")
    git_repo.commit("feature", filename="feature.txt", content="feature\n")
    git_repo.checkout("main")
    initialize(stackman_db_path)
    repo_key = git_repo.canonical_repo_key()
    upsert_branch(
        stackman_db_path,
        repo_root=repo_key,
        branch_name="feature",
        parent_branch_name="main",
        fork_point_sha=git_repo.merge_base("feature", "main"),
    )
    label_branch(stackman_db_path, repo_key, "feature", "stack-feature", anchor_branch_name="main")

    result = CliRunner().invoke(
        cli,
        ["--db-path", str(stackman_db_path), "--repo", str(git_repo.root), "list"],
    )

    assert result.exit_code == 0, result.output
    assert "Tracked branches in" in result.output
    assert "feature" in result.output
    assert "stack-feature" not in result.output
