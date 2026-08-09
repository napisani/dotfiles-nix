# Stackman Sync History Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real-git regression tests that prove `stackman sync` rewrites only inherited stack ancestry while preserving intended branch-local history.

**Architecture:** Extend `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py` with three focused end-to-end tests that use the existing temporary git repo fixture and sqlite-backed stack metadata. Keep helper logic local to that file so the assertions stay readable: one small group of helpers for commit messages, commit counts, and inherited SHA ancestry, then one test per requested scenario.

**Tech Stack:** Python, pytest, sqlite store helpers, git CLI via `GitRepoFixture`, StackmanApp sync command

---

### Task 1: Add local history assertion helpers and the preserved-post-fork-history regression test

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`

- [ ] **Step 1: Write the failing test and helper skeletons**

Add these helpers near the top of `test_sync_command.py`, below `_ConflictResolverInput`, and add the new test below the existing sync tests:

```python
def _commit_subjects_in_range(git_repo, rev_range: str) -> list[str]:
    output = git_repo.git("log", "--reverse", "--format=%s", rev_range)
    return [line for line in output.splitlines() if line]


def _commit_count_in_range(git_repo, rev_range: str) -> int:
    return int(git_repo.git("rev-list", "--count", rev_range))


def _ancestry_from(git_repo, ref: str) -> list[str]:
    output = git_repo.git("rev-list", ref)
    return [line for line in output.splitlines() if line]


def test_sync_retains_post_fork_history_while_replacing_older_ancestry(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("branch1", from_ref="main")
    git_repo.commit("branch1 base", filename="branch1.txt", content="branch1 base\n")
    git_repo.checkout_new("branch2", from_ref="branch1")
    fork_branch2 = git_repo.merge_base("branch2", "branch1")
    git_repo.commit("branch2 commit 1", filename="branch2.txt", content="one\n")
    git_repo.commit("branch2 commit 2", filename="branch2.txt", content="two\n")

    expected_subjects = _commit_subjects_in_range(git_repo, f"{fork_branch2}..branch2")
    expected_count = _commit_count_in_range(git_repo, f"{fork_branch2}..branch2")

    initialize(stackman_db_path)
    upsert_branch(
        stackman_db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="branch1",
        parent_branch_name="main",
        fork_point_sha=git_repo.merge_base("branch1", "main"),
    )
    upsert_branch(
        stackman_db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="branch2",
        parent_branch_name="branch1",
        fork_point_sha=fork_branch2,
    )
    label_branch(stackman_db_path, git_repo.canonical_repo_key(), "branch1", "stack-history")

    git_repo.checkout("branch1")
    git_repo.commit("branch1 moves", filename="branch1.txt", content="branch1 moves\n")
    new_parent_tip = git_repo.rev_parse("branch1")
    expected_parent_ancestry = _ancestry_from(git_repo, new_parent_tip)

    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
    )
    assert app.sync(stack_id="stack-history") == 0

    tracked = get_branch(stackman_db_path, git_repo.canonical_repo_key(), "branch2")
    assert tracked is not None
    assert tracked.fork_point_sha == new_parent_tip
    assert _commit_count_in_range(git_repo, f"{new_parent_tip}..branch2") == expected_count
    assert _commit_subjects_in_range(git_repo, f"{new_parent_tip}..branch2") == expected_subjects
    assert _ancestry_from(git_repo, new_parent_tip) == expected_parent_ancestry
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py::test_sync_retains_post_fork_history_while_replacing_older_ancestry -v`
Expected: FAIL because the ancestry assertion is incomplete and does not yet prove that `branch2` inherits the exact parent SHA chain from the new fork-point backward.

- [ ] **Step 3: Write the minimal test implementation fix**

Tighten the final ancestry assertion so it compares the child branch ancestry after dropping the preserved post-fork commits against the parent ancestry captured at the new fork-point:

```python
    child_ancestry = _ancestry_from(git_repo, "branch2")
    preserved_count = _commit_count_in_range(git_repo, f"{new_parent_tip}..branch2")
    assert child_ancestry[preserved_count:] == expected_parent_ancestry
```

Leave the earlier count and subject assertions in place. Together these prove:

- the post-fork branch-local history was replayed intact
- the inherited base history from the fork-point backward now exactly matches `branch1` by SHA

- [ ] **Step 4: Run the test to verify it passes**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py::test_sync_retains_post_fork_history_while_replacing_older_ancestry -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman/tests/test_sync_command.py
git commit -m "test: verify sync preserves post-fork branch history"
```

### Task 2: Add the middle-branch-change regression test

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`

- [ ] **Step 1: Write the failing test**

Add this new test below the previous one:

```python
def test_sync_rebases_only_tail_when_middle_branch_changes(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("branch1", from_ref="main")
    git_repo.commit("branch1 commit", filename="branch1.txt", content="branch1\n")
    git_repo.checkout_new("branch2", from_ref="branch1")
    fork_branch2 = git_repo.merge_base("branch2", "branch1")
    git_repo.commit("branch2 original", filename="branch2.txt", content="branch2 original\n")
    git_repo.checkout_new("branch3", from_ref="branch2")
    fork_branch3 = git_repo.merge_base("branch3", "branch2")
    git_repo.commit("branch3 commit 1", filename="branch3.txt", content="branch3 one\n")
    git_repo.commit("branch3 commit 2", filename="branch3.txt", content="branch3 two\n")

    branch1_before = git_repo.rev_parse("branch1")
    branch3_subjects_before = _commit_subjects_in_range(git_repo, f"{fork_branch3}..branch3")
    branch3_count_before = _commit_count_in_range(git_repo, f"{fork_branch3}..branch3")

    initialize(stackman_db_path)
    upsert_branch(
        stackman_db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="branch1",
        parent_branch_name="main",
        fork_point_sha=git_repo.merge_base("branch1", "main"),
    )
    upsert_branch(
        stackman_db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="branch2",
        parent_branch_name="branch1",
        fork_point_sha=fork_branch2,
    )
    upsert_branch(
        stackman_db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="branch3",
        parent_branch_name="branch2",
        fork_point_sha=fork_branch3,
    )
    label_branch(stackman_db_path, git_repo.canonical_repo_key(), "branch1", "stack-middle")

    git_repo.checkout("branch2")
    git_repo.commit("branch2 new tip", filename="branch2.txt", content="branch2 new tip\n")
    branch2_after_manual_commit = git_repo.rev_parse("branch2")
    expected_parent_ancestry = _ancestry_from(git_repo, branch2_after_manual_commit)

    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
    )
    assert app.sync(stack_id="stack-middle") == 0

    assert git_repo.rev_parse("branch1") == branch1_before
    assert git_repo.rev_parse("branch2") == branch2_after_manual_commit
    assert _commit_count_in_range(git_repo, f"{branch2_after_manual_commit}..branch3") == branch3_count_before
    assert _commit_subjects_in_range(git_repo, f"{branch2_after_manual_commit}..branch3") == branch3_subjects_before
    assert _ancestry_from(git_repo, branch2_after_manual_commit) == expected_parent_ancestry
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py::test_sync_rebases_only_tail_when_middle_branch_changes -v`
Expected: FAIL because the test does not yet assert that `branch3` tip changed and that the child ancestry after preserved commits matches `branch2` from the new fork-point backward.

- [ ] **Step 3: Write the minimal test implementation fix**

Add the missing tip-change and ancestry assertions:

```python
    branch3_after = git_repo.rev_parse("branch3")
    assert branch3_after != git_repo.rev_parse(fork_branch3)

    child_ancestry = _ancestry_from(git_repo, "branch3")
    preserved_count = _commit_count_in_range(git_repo, f"{branch2_after_manual_commit}..branch3")
    assert child_ancestry[preserved_count:] == expected_parent_ancestry
```

Store the original `branch3` tip before sync and compare against that value instead of `fork_branch3`:

```python
    branch3_before = git_repo.rev_parse("branch3")
    ...
    branch3_after = git_repo.rev_parse("branch3")
    assert branch3_after != branch3_before
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py::test_sync_rebases_only_tail_when_middle_branch_changes -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman/tests/test_sync_command.py
git commit -m "test: verify sync only rebases tail after middle change"
```

### Task 3: Add the root-branch-change plus second-sync-no-op regression test

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`

- [ ] **Step 1: Write the failing test**

Add this new test below the middle-branch case:

```python
def test_sync_rebases_tail_after_root_change_and_second_run_is_noop(
    git_repo,
    stackman_db_path,
) -> None:
    git_repo.checkout_new("branch1", from_ref="main")
    git_repo.commit("branch1 original", filename="branch1.txt", content="branch1 original\n")
    git_repo.checkout_new("branch2", from_ref="branch1")
    fork_branch2 = git_repo.merge_base("branch2", "branch1")
    git_repo.commit("branch2 commit 1", filename="branch2.txt", content="branch2 one\n")
    git_repo.commit("branch2 commit 2", filename="branch2.txt", content="branch2 two\n")
    git_repo.checkout_new("branch3", from_ref="branch2")
    fork_branch3 = git_repo.merge_base("branch3", "branch2")
    git_repo.commit("branch3 commit 1", filename="branch3.txt", content="branch3 one\n")
    git_repo.commit("branch3 commit 2", filename="branch3.txt", content="branch3 two\n")

    branch2_subjects_before = _commit_subjects_in_range(git_repo, f"{fork_branch2}..branch2")
    branch2_count_before = _commit_count_in_range(git_repo, f"{fork_branch2}..branch2")
    branch3_subjects_before = _commit_subjects_in_range(git_repo, f"{fork_branch3}..branch3")
    branch3_count_before = _commit_count_in_range(git_repo, f"{fork_branch3}..branch3")

    initialize(stackman_db_path)
    upsert_branch(
        stackman_db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="branch1",
        parent_branch_name="main",
        fork_point_sha=git_repo.merge_base("branch1", "main"),
    )
    upsert_branch(
        stackman_db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="branch2",
        parent_branch_name="branch1",
        fork_point_sha=fork_branch2,
    )
    upsert_branch(
        stackman_db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="branch3",
        parent_branch_name="branch2",
        fork_point_sha=fork_branch3,
    )
    label_branch(stackman_db_path, git_repo.canonical_repo_key(), "branch1", "stack-root")

    git_repo.checkout("branch1")
    git_repo.commit("branch1 new tip", filename="branch1.txt", content="branch1 new tip\n")
    branch1_new_tip = git_repo.rev_parse("branch1")

    first_stdout = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=first_stdout,
        stderr=io.StringIO(),
    )
    assert app.sync(stack_id="stack-root") == 0

    branch1_after_first = git_repo.rev_parse("branch1")
    branch2_after_first = git_repo.rev_parse("branch2")
    branch3_after_first = git_repo.rev_parse("branch3")

    assert branch1_after_first == branch1_new_tip
    assert _commit_count_in_range(git_repo, f"{branch1_new_tip}..branch2") == branch2_count_before
    assert _commit_subjects_in_range(git_repo, f"{branch1_new_tip}..branch2") == branch2_subjects_before
    assert _commit_count_in_range(git_repo, f"{branch2_after_first}..branch3") == branch3_count_before
    assert _commit_subjects_in_range(git_repo, f"{branch2_after_first}..branch3") == branch3_subjects_before

    second_stdout = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=second_stdout,
        stderr=io.StringIO(),
    )
    assert app.sync(stack_id="stack-root") == 0

    assert git_repo.rev_parse("branch1") == branch1_after_first
    assert git_repo.rev_parse("branch2") == branch2_after_first
    assert git_repo.rev_parse("branch3") == branch3_after_first
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py::test_sync_rebases_tail_after_root_change_and_second_run_is_noop -v`
Expected: FAIL because the test does not yet prove the inherited ancestry matches parent SHAs after the first sync, and does not yet check the second-run skip output.

- [ ] **Step 3: Write the minimal test implementation fix**

Add explicit inherited-ancestry and second-run output assertions:

```python
    branch1_ancestry = _ancestry_from(git_repo, branch1_new_tip)
    branch2_ancestry = _ancestry_from(git_repo, "branch2")
    branch3_ancestry = _ancestry_from(git_repo, "branch3")

    assert branch2_ancestry[branch2_count_before:] == branch1_ancestry
    assert branch3_ancestry[branch3_count_before:] == _ancestry_from(git_repo, branch2_after_first)

    second_output = second_stdout.getvalue()
    assert "stored fork-point already matches current 'branch1' tip" in second_output
    assert "stored fork-point already matches current 'branch2' tip" in second_output
```

If the second-run message wording differs slightly, match the exact existing output from `sync.py` rather than weakening the assertion to a vague substring.

- [ ] **Step 4: Run the test to verify it passes**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py::test_sync_rebases_tail_after_root_change_and_second_run_is_noop -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman/tests/test_sync_command.py
git commit -m "test: verify sync is stable after root branch change"
```

### Task 4: Verify the targeted sync suite and clean up any assertion mismatches

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`

- [ ] **Step 1: Run the three new regressions together**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py -k "retains_post_fork_history or only_tail_when_middle_branch_changes or second_run_is_noop" -v`
Expected: PASS

- [ ] **Step 2: Run the full sync command suite**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py -v`
Expected: PASS

- [ ] **Step 3: If output assertions are brittle, tighten them to exact current messaging**

If any assertion fails because the skip output wording differs, update the assertion text in `test_sync_command.py` to match the exact existing message emitted by `mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py`:

```python
assert (
    "stored fork-point already matches current 'branch1' tip" in second_output
)
assert (
    "stored fork-point already matches current 'branch2' tip" in second_output
)
```

Do not relax the assertion to something generic like `"already matches"`; keep the parent branch names in the expectation.

- [ ] **Step 4: Run the broader stackman test suite**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests -q`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman/tests/test_sync_command.py
git commit -m "test: add stacked sync ancestry regression coverage"
```
