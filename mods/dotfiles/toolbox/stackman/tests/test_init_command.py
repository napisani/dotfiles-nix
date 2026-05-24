from __future__ import annotations

import io

from stackman.app import StackmanApp
from stackman.store import get_branch, get_stack, initialize, list_branch_labels


def test_init_with_explicit_parent_persists_branch_lineage(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("feature", from_ref="main")
    git_repo.commit("feature commit", filename="feature.txt", content="feature\n")

    stdout = io.StringIO()
    stderr = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout,
        stderr=stderr,
    )

    exit_code = app.init(parent="main", stacks=("stack-1",))

    assert exit_code == 0
    assert stderr.getvalue() == ""
    out = stdout.getvalue()
    assert "Tracked branch 'feature' with parent 'main'" in out
    assert "Stack label(s): stack-1." in out

    status_stdout = io.StringIO()
    status_app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=status_stdout,
        stderr=io.StringIO(),
    )
    status_exit = status_app.status()

    assert status_exit == 0
    rendered = status_stdout.getvalue()
    assert "branch: feature" in rendered
    assert "parent: main" in rendered
    assert "labels: stack-1" in rendered


def test_init_with_csv_branch_chain_tracks_lineage_under_one_stack_label(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("stack1", from_ref="main")
    git_repo.commit("stack1 commit", filename="stack1.txt", content="stack1\n")
    git_repo.checkout_new("stack2", from_ref="stack1")
    git_repo.commit("stack2 commit", filename="stack2.txt", content="stack2\n")

    calls: list[str] = []

    def factory() -> str:
        calls.append("x")
        return "sm_csv_chain"

    stdout = io.StringIO()
    stderr = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout,
        stderr=stderr,
        stack_id_factory=factory,
    )

    exit_code = app.init(branches="main,stack1,stack2")

    assert exit_code == 0
    assert stderr.getvalue() == ""
    assert calls == ["x"]

    repo_key = git_repo.canonical_repo_key()
    stack1 = get_branch(stackman_db_path, repo_key, "stack1")
    stack2 = get_branch(stackman_db_path, repo_key, "stack2")
    assert stack1 is not None
    assert stack1.parent_branch_name == "main"
    assert stack1.fork_point_sha == git_repo.merge_base("stack1", "main")
    assert stack2 is not None
    assert stack2.parent_branch_name == "stack1"
    assert stack2.fork_point_sha == git_repo.merge_base("stack2", "stack1")
    assert list_branch_labels(stackman_db_path, repo_key, "stack1") == ["sm_csv_chain"]
    assert list_branch_labels(stackman_db_path, repo_key, "stack2") == ["sm_csv_chain"]

    stack = get_stack(stackman_db_path, "sm_csv_chain")
    assert stack is not None
    assert stack.anchor_branch_name == "main"
    out = stdout.getvalue()
    assert "Tracked stack chain 'main' -> 'stack1' -> 'stack2'." in out
    assert "Stack label(s): sm_csv_chain." in out


def test_init_without_parent_uses_interactive_selection(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("branch_a", from_ref="main")
    git_repo.commit("branch a commit", filename="a.txt", content="a\n")
    git_repo.checkout("main")
    git_repo.checkout_new("branch_c", from_ref="main")
    git_repo.commit("branch c commit", filename="c.txt", content="c\n")

    stdout = io.StringIO()
    stderr = io.StringIO()
    seen: dict[str, object] = {}

    def chooser(prompt: str, candidates):
        seen["prompt"] = prompt
        seen["candidates"] = candidates
        return "main"

    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout,
        stderr=stderr,
        parent_chooser=chooser,
    )

    exit_code = app.init()

    assert exit_code == 0
    assert stderr.getvalue() == ""
    assert "Ambiguous parent branch" in str(seen["prompt"])
    candidate_names = [candidate.branch_name for candidate in seen["candidates"]]
    assert candidate_names == ["main", "branch_a"]
    out = stdout.getvalue()
    assert "Tracked branch 'branch_c' with parent 'main'" in out
    assert "Stack label(s):" in out
    assert "auto-generated" in out
    initialize(stackman_db_path)
    labels = list_branch_labels(stackman_db_path, git_repo.canonical_repo_key(), "branch_c")
    assert len(labels) == 1
    assert labels[0].startswith("sm_")


def test_init_inherits_all_stack_labels_from_tracked_parent(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("parent_br", from_ref="main")
    git_repo.commit("p", filename="p.txt", content="p\n")
    git_repo.checkout_new("child_br", from_ref="parent_br")
    git_repo.commit("c", filename="c.txt", content="c\n")

    calls: list[str] = []

    def factory() -> str:
        calls.append("factory")
        return "sm_shared_line"

    parent_app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
        stack_id_factory=factory,
    )
    git_repo.checkout("parent_br")
    assert parent_app.init(parent="main", stacks=("user-a", "user-b")) == 0

    git_repo.checkout("child_br")
    child_app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
        stack_id_factory=factory,
    )
    assert child_app.init(parent="parent_br") == 0
    assert calls == []

    initialize(stackman_db_path)
    assert set(list_branch_labels(stackman_db_path, git_repo.canonical_repo_key(), "child_br")) == {
        "user-a",
        "user-b",
    }


def test_init_linear_stack_shares_one_auto_id(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("line_a", from_ref="main")
    git_repo.commit("a", filename="la.txt", content="a\n")
    git_repo.checkout_new("line_b", from_ref="line_a")
    git_repo.commit("b", filename="lb.txt", content="b\n")

    calls: list[str] = []

    def factory() -> str:
        calls.append("x")
        return "sm_line_root"

    root_app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
        stack_id_factory=factory,
    )
    git_repo.checkout("line_a")
    assert root_app.init(parent="main") == 0
    assert len(calls) == 1

    child_app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
        stack_id_factory=factory,
    )
    git_repo.checkout("line_b")
    assert child_app.init(parent="line_a") == 0
    assert len(calls) == 1

    initialize(stackman_db_path)
    assert list_branch_labels(stackman_db_path, git_repo.canonical_repo_key(), "line_a") == ["sm_line_root"]
    assert list_branch_labels(stackman_db_path, git_repo.canonical_repo_key(), "line_b") == ["sm_line_root"]


def test_init_uses_injected_stack_id_factory(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("solo", from_ref="main")
    git_repo.commit("solo commit", filename="solo.txt", content="solo\n")

    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
        stack_id_factory=lambda: "sm_custom000001",
    )
    assert app.init(parent="main") == 0
    initialize(stackman_db_path)
    assert list_branch_labels(stackman_db_path, git_repo.canonical_repo_key(), "solo") == ["sm_custom000001"]


def test_init_records_anchor_for_new_auto_stack(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("root_feature", from_ref="main")
    git_repo.commit("root", filename="root.txt", content="root\n")

    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
        stack_id_factory=lambda: "sm_root",
    )

    assert app.init(parent="main") == 0
    stack = get_stack(stackman_db_path, "sm_root")
    assert stack is not None
    assert stack.anchor_branch_name == "main"


def test_init_inherited_stack_label_does_not_change_anchor(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("root_feature", from_ref="main")
    git_repo.commit("root", filename="root.txt", content="root\n")
    git_repo.checkout_new("child_feature", from_ref="root_feature")
    git_repo.commit("child", filename="child.txt", content="child\n")

    root_app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
        stack_id_factory=lambda: "sm_root",
    )
    git_repo.checkout("root_feature")
    assert root_app.init(parent="main") == 0

    child_app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
    )
    git_repo.checkout("child_feature")
    assert child_app.init(parent="root_feature") == 0

    stack = get_stack(stackman_db_path, "sm_root")
    assert stack is not None
    assert stack.anchor_branch_name == "main"


def test_init_explicit_stack_fills_but_does_not_overwrite_anchor(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("first", from_ref="main")
    git_repo.commit("first", filename="first.txt", content="first\n")
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
    )
    assert app.init(parent="main", stacks=("custom",)) == 0

    git_repo.checkout("main")
    git_repo.checkout_new("second", from_ref="first")
    git_repo.commit("second", filename="second.txt", content="second\n")
    assert app.init(parent="first", stacks=("custom",)) == 0

    stack = get_stack(stackman_db_path, "custom")
    assert stack is not None
    assert stack.anchor_branch_name == "main"
