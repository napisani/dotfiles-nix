from __future__ import annotations

import io

from stackman.app import StackmanApp
from stackman.store import initialize, list_branch_labels


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
