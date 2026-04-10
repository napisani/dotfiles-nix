from __future__ import annotations

import io

from stackman.app import StackmanApp


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
    assert "Tracked branch 'feature' with parent 'main'" in stdout.getvalue()

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
    assert "Tracked branch 'branch_c' with parent 'main'" in stdout.getvalue()
