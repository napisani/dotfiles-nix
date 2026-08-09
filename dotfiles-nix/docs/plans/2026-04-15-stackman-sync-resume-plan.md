# Stackman Sync Resume And Squash Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `stackman sync` update tracked fork-points after successful rebases, optionally squash branch history before rebasing, and pause in-place for conflict resolution until the rebase completes or aborts.

**Architecture:** Keep the existing `git rebase --onto <parent_tip> <stored_fork_point>` sync algorithm, but treat the successful rebase target as the new stored fork-point. Add an optional per-branch squash step before rebasing that collapses `2+` post-fork commits into one commit while preserving the first commit message. Extend the sync command with a small interactive wait loop that detects whether a conflicted rebase is still active, completed, or aborted before continuing. Persist metadata only after successful completion.

**Tech Stack:** Python, pytest, SQLite store helpers, git CLI worktrees

---

### Task 1: Add store support for advancing a branch fork-point

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/store/branches.py`
- Test: `mods/dotfiles/toolbox/stackman/tests/test_db.py`

**Step 1: Write the failing test**

Add a test in `test_db.py` that:

```python
def test_update_branch_fork_point(stackman_db_path: Path, git_repo: GitRepo) -> None:
    initialize(stackman_db_path)
    tracked = upsert_branch(
        stackman_db_path,
        git_repo.root,
        "feature",
        parent_branch_name="main",
        fork_point_sha="abc1234",
    )

    update_branch_fork_point(stackman_db_path, "feature", "def5678")

    refreshed = get_branch(stackman_db_path, "feature")
    assert refreshed is not None
    assert refreshed.fork_point_sha == "def5678"
```

**Step 2: Run test to verify it fails**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_db.py::test_update_branch_fork_point -v`
Expected: FAIL because `update_branch_fork_point` does not exist yet.

**Step 3: Write minimal implementation**

Add a function in `store/branches.py`:

```python
def update_branch_fork_point(db_path: Path, branch_name: str, fork_point_sha: str) -> None:
    with connect(db_path) as conn:
        conn.execute(
            "UPDATE branches SET fork_point_sha = ? WHERE branch_name = ?",
            (fork_point_sha, branch_name),
        )
```

Export it from `store/__init__.py` if the command layer imports through that facade.

**Step 4: Run test to verify it passes**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_db.py::test_update_branch_fork_point -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman/src/stackman/store/branches.py \
        mods/dotfiles/toolbox/stackman/src/stackman/store/__init__.py \
        mods/dotfiles/toolbox/stackman/tests/test_db.py
git commit -m "feat: add branch fork-point update helper"
```

### Task 2: Skip already-synced branches and advance fork-point after successful rebases

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py`
- Test: `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`

**Step 1: Write the failing test**

Add a sync regression test that:

```python
def test_sync_second_run_skips_branch_already_synced_to_parent_tip(...) -> None:
    # initialize repo and tracked stack
    # first sync rebases child onto moved parent
    assert app.sync(stack_id="stack-1") == 0

    # second sync should be a no-op for that branch
    before = git_output(repo.root, "rev-parse", "child")
    assert app.sync(stack_id="stack-1") == 0
    after = git_output(repo.root, "rev-parse", "child")
    assert after == before
```

Add assertions that the stored `fork_point_sha` equals the parent tip used during the first successful sync.

**Step 2: Run test to verify it fails**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py::test_sync_second_run_skips_branch_already_synced_to_parent_tip -v`
Expected: FAIL because the second sync currently rebases again.

**Step 3: Write minimal implementation**

In `commands/sync.py`:

- Capture `onto = rev_parse(parent_name)` before rebasing.
- If `record.fork_point_sha == onto`, skip the branch with a status message.
- After a successful `rebase_onto(...)`, call `update_branch_fork_point(ctx.db_path, branch_name, onto)`.

Use the `onto` value captured before the rebase as the persisted fork-point.

**Step 4: Run test to verify it passes**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py::test_sync_second_run_skips_branch_already_synced_to_parent_tip -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py \
        mods/dotfiles/toolbox/stackman/tests/test_sync_command.py
git commit -m "fix: persist sync fork-point after successful rebase"
```

### Task 3: Add interactive conflict wait loop to sync

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py`
- Test: `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`
- Test: `mods/dotfiles/toolbox/stackman/tests/test_app.py`

**Step 1: Write the failing tests**

Add targeted tests that stub or simulate the rebase state:

```python
def test_sync_waits_for_enter_until_rebase_finishes(...) -> None:
    stdin = io.StringIO("\n")
    app = StackmanApp(..., stdin=stdin, ...)
    # mock rebase call to fail first
    # mock rebase_in_progress_any_linked/worktree checks to return
    # True, then False after user "continues"
    assert app.sync(stack_id="stack-1") == 0

def test_sync_exits_non_zero_if_paused_rebase_was_aborted(...) -> None:
    stdin = io.StringIO("\n")
    app = StackmanApp(..., stdin=stdin, ...)
    # simulate conflict followed by no rebase-in-progress and unchanged branch tip
    assert app.sync(stack_id="stack-1") != 0
```

Prefer narrow tests around helper functions if direct end-to-end simulation becomes brittle.

**Step 2: Run tests to verify they fail**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py -k "waits_for_enter or aborted" -v`
Expected: FAIL because sync currently exits immediately on conflict.

**Step 3: Write minimal implementation**

Add a helper in `commands/sync.py` similar to:

```python
def _wait_for_conflict_resolution(ctx: AppContext, worktree: Path) -> bool:
    while True:
        ctx.stdout.write("[stackman] Resolve conflicts, run `git rebase --continue` or `git rebase --abort`, then press Enter to resume.\n")
        ctx.stdout.flush()
        ctx.stdin.readline()
        if rebase_in_progress(worktree):
            ctx.stdout.write("[stackman] Rebase still in progress.\n")
            continue
        return True
```

Then, in the conflict path:

- detect the branch tip before the failing rebase
- after the wait loop, if the rebase is no longer active:
  - if the branch tip changed to a successful rebased state, update the fork-point and continue
  - otherwise treat it as aborted and return non-zero

If a more explicit git signal exists in the current codebase, use it instead of branch-tip comparison.

**Step 4: Run tests to verify they pass**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py -k "waits_for_enter or aborted" -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py \
        mods/dotfiles/toolbox/stackman/tests/test_sync_command.py \
        mods/dotfiles/toolbox/stackman/tests/test_app.py
git commit -m "feat: pause sync for conflict resolution"
```

### Task 4: Verify the full sync behavior and clean up messages

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py`
- Test: `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`

**Step 1: Add or tighten assertions around user-visible output**

Ensure tests verify:

- skipped branch message when fork-point already matches parent tip
- conflict pause instructions
- aborted rebase message returns non-zero
- resumed sync continues to later branches after successful conflict resolution

**Step 2: Run targeted sync suite**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py -v`
Expected: PASS

**Step 3: Run the broader stackman test suite**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests -q`
Expected: PASS

**Step 4: Dry-run review of the implementation**

Check:

- no metadata update on failed or aborted rebases
- persisted fork-point uses the pre-rebase parent tip, not the post-rebase branch tip
- interactive prompt uses `ctx.stdin`/`ctx.stdout`, so tests and CLI both behave correctly

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py \
        mods/dotfiles/toolbox/stackman/tests/test_sync_command.py
git commit -m "test: verify sync resume behavior"
```

### Task 5: Add git helpers and CLI wiring for `stackman sync --squash`

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/git_ops.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/cli.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/app.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py`
- Test: `mods/dotfiles/toolbox/stackman/tests/test_cli.py`

**Step 1: Write the failing tests**

Add a CLI coverage test that checks:

```python
def test_sync_subcommand_supports_squash_flag() -> None:
    runner = CliRunner()
    result = runner.invoke(cli, ["sync", "--help"])
    assert result.exit_code == 0
    assert "--squash" in result.output
```

**Step 2: Run test to verify it fails**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_cli.py::test_sync_subcommand_supports_squash_flag -v`
Expected: FAIL because `--squash` is not wired yet.

**Step 3: Write minimal implementation**

- Add helper functions in `git_ops.py` to:
  - list commits in `fork_point..HEAD` in chronological order
  - read a commit message by SHA
  - squash branch commits with `git reset --soft <fork_point>` followed by `git commit -F -`
- Add `--squash` to `cli.py`
- Thread `squash: bool` through `StackmanApp.sync(...)` and `commands/sync.py`

**Step 4: Run test to verify it passes**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_cli.py::test_sync_subcommand_supports_squash_flag -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman/src/stackman/git_ops.py \
        mods/dotfiles/toolbox/stackman/src/stackman/cli.py \
        mods/dotfiles/toolbox/stackman/src/stackman/app.py \
        mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py \
        mods/dotfiles/toolbox/stackman/tests/test_cli.py
git commit -m "feat: wire stackman sync squash flag"
```

### Task 6: Implement squash behavior with dedicated sync tests

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/git_ops.py`
- Test: `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`

**Step 1: Write the failing tests**

Add dedicated sync tests for:

```python
def test_sync_squash_collapses_multiple_post_fork_commits(...) -> None:
    # branch has 3 commits after fork-point
    # sync with squash should leave exactly 1 commit after parent tip

def test_sync_squash_leaves_single_post_fork_commit_unchanged(...) -> None:
    # branch has 1 commit after fork-point
    # sync with squash should keep same commit id until rebase rewrites it

def test_sync_dry_run_reports_squash_plan(...) -> None:
    # dry run should mention squash or skip-squash for each branch
```

Add assertions for:

- commit count after fork-point before and after sync
- preserved first commit message for squashed branches
- updated stored `fork_point_sha` after successful rebase

**Step 2: Run tests to verify they fail**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py -k squash -v`
Expected: FAIL because squash behavior does not exist yet.

**Step 3: Write minimal implementation**

In `commands/sync.py`:

- before rebasing, if `squash` is enabled:
  - count commits in `fork_point_sha..HEAD`
  - if count >= 2, squash branch history and emit a status line
  - if count <= 1, emit a skip-squash status line
- preserve the first post-fork commit message when creating the squashed commit
- include squash details in `--dry-run`

**Step 4: Run tests to verify they pass**

Run: `uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py -k squash -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py \
        mods/dotfiles/toolbox/stackman/src/stackman/git_ops.py \
        mods/dotfiles/toolbox/stackman/tests/test_sync_command.py
git commit -m "feat: squash branch history during sync"
```

### Task 7: Run the full Stackman suite with squash coverage

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`
- Modify: `mods/dotfiles/toolbox/stackman/tests/test_cli.py`

**Step 1: Run focused suites**

Run:

```bash
uv run pytest mods/dotfiles/toolbox/stackman/tests/test_cli.py -v
uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py -v
```

Expected: PASS

**Step 2: Run the full Stackman suite**

Run:

```bash
uv run pytest mods/dotfiles/toolbox/stackman/tests -q
```

Expected: PASS

**Step 3: Final review checklist**

Check:

- `--squash` only rewrites branches with `2+` post-fork commits
- single-commit branches are left unchanged
- dry-run prints squash intent without modifying history
- squash happens before rebase
- fork-point metadata still advances only after successful rebase completion

**Step 4: Commit**

```bash
git add mods/dotfiles/toolbox/stackman/tests/test_cli.py \
        mods/dotfiles/toolbox/stackman/tests/test_sync_command.py
git commit -m "test: cover sync squash behavior"
```
