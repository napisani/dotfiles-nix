# Stackman Anchor Branch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add stack-level anchor branches so root stack branches rebase from the recorded anchor during sync.

**Architecture:** Store `anchor_branch_name` on `stacks`, expose it through `StackRecord`, and keep stack creation idempotent without silently overwriting existing anchors. Sync planning accepts the anchor so ancestor walking stops at the anchor even when that branch is tracked elsewhere, and sync execution uses the anchor as the rebase target for root branches.

**Tech Stack:** Python 3.12, SQLite via stdlib `sqlite3`, Click CLI, pytest, real Git integration tests.

---

## File Structure

- `mods/dotfiles/toolbox/stackman/src/stackman/models.py`: add `StackRecord.anchor_branch_name`.
- `mods/dotfiles/toolbox/stackman/src/stackman/store/schema.py`: add and migrate `stacks.anchor_branch_name`.
- `mods/dotfiles/toolbox/stackman/src/stackman/store/rows.py`: hydrate stack anchors.
- `mods/dotfiles/toolbox/stackman/src/stackman/store/stacks.py`: create/get/fill stack anchors and let `label_branch` pass an anchor.
- `mods/dotfiles/toolbox/stackman/src/stackman/store/__init__.py`: export new stack lookup helpers.
- `mods/dotfiles/toolbox/stackman/src/stackman/commands/init_command.py`: set anchors for new explicit or auto-created stack ids.
- `mods/dotfiles/toolbox/stackman/src/stackman/sync_plan.py`: carry `anchor_branch_name` and stop root resolution at the anchor.
- `mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py`: resolve/backfill the anchor, print it, and use it for root branch rebases.
- `mods/dotfiles/toolbox/stackman/tests/test_db.py`: persistence tests.
- `mods/dotfiles/toolbox/stackman/tests/test_init_command.py`: init/anchor tests.
- `mods/dotfiles/toolbox/stackman/tests/test_sync_plan.py`: anchor-aware root planning tests.
- `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`: dry-run and integration sync tests.

## Task 1: Stack Anchor Persistence

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/tests/test_db.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/models.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/store/schema.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/store/rows.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/store/stacks.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/store/__init__.py`

- [x] **Step 1: Write failing persistence tests**

Add tests:

```python
from stackman.store import create_stack, get_stack


def test_stack_anchor_is_persisted(tmp_path: Path) -> None:
    db_path = tmp_path / "stackman.db"
    initialize(db_path)

    created = create_stack(db_path, "stack-a", anchor_branch_name="release/1.2")
    loaded = get_stack(db_path, "stack-a")

    assert created.anchor_branch_name == "release/1.2"
    assert loaded is not None
    assert loaded.anchor_branch_name == "release/1.2"


def test_stack_anchor_is_filled_but_not_overwritten(tmp_path: Path) -> None:
    db_path = tmp_path / "stackman.db"
    initialize(db_path)

    create_stack(db_path, "stack-a")
    create_stack(db_path, "stack-a", anchor_branch_name="main")
    create_stack(db_path, "stack-a", anchor_branch_name="release/1.2")

    loaded = get_stack(db_path, "stack-a")
    assert loaded is not None
    assert loaded.anchor_branch_name == "main"
```

- [x] **Step 2: Run persistence tests and verify RED**

Run:

```bash
rtk uv run pytest mods/dotfiles/toolbox/stackman/tests/test_db.py::test_stack_anchor_is_persisted mods/dotfiles/toolbox/stackman/tests/test_db.py::test_stack_anchor_is_filled_but_not_overwritten -q
```

Expected: FAIL because `get_stack` is not exported or `StackRecord` lacks `anchor_branch_name`.

- [x] **Step 3: Implement minimal persistence**

Add `anchor_branch_name` to `StackRecord`, schema, migration, row hydration, and stack helpers.

`create_stack` should use:

```sql
ON CONFLICT(id) DO UPDATE SET
    name = COALESCE(excluded.name, stacks.name),
    anchor_branch_name = COALESCE(stacks.anchor_branch_name, excluded.anchor_branch_name)
```

- [x] **Step 4: Run persistence tests and verify GREEN**

Run the same command from Step 2. Expected: PASS.

## Task 2: Init Stores and Preserves Anchors

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/tests/test_init_command.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/commands/init_command.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/store/stacks.py`

- [x] **Step 1: Write failing init tests**

Add tests:

```python
from stackman.store import get_stack


def test_init_records_anchor_for_new_auto_stack(git_repo, stackman_db_path) -> None:
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


def test_init_inherited_stack_label_does_not_change_anchor(git_repo, stackman_db_path) -> None:
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


def test_init_explicit_stack_fills_but_does_not_overwrite_anchor(git_repo, stackman_db_path) -> None:
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
```

- [x] **Step 2: Run init tests and verify RED**

Run:

```bash
rtk uv run pytest mods/dotfiles/toolbox/stackman/tests/test_init_command.py::test_init_records_anchor_for_new_auto_stack mods/dotfiles/toolbox/stackman/tests/test_init_command.py::test_init_inherited_stack_label_does_not_change_anchor mods/dotfiles/toolbox/stackman/tests/test_init_command.py::test_init_explicit_stack_fills_but_does_not_overwrite_anchor -q
```

Expected: FAIL because `init` does not pass anchors when labeling new stacks.

- [x] **Step 3: Implement minimal init anchor assignment**

When `stacks` is explicit, call `label_branch(..., anchor_branch_name=parent_branch)`.

When auto-generating a new stack because the parent has no labels, call `label_branch(..., anchor_branch_name=parent_branch)`.

When inheriting parent labels, call `label_branch(..., anchor_branch_name=None)`.

- [x] **Step 4: Run init tests and verify GREEN**

Run the same command from Step 2. Expected: PASS.

## Task 3: Anchor-Aware Sync Planning

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/tests/test_sync_plan.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/sync_plan.py`

- [x] **Step 1: Write failing sync-plan tests**

Add tests:

```python
def test_sync_plan_stops_root_resolution_at_tracked_anchor() -> None:
    branches = [
        _branch("release_base", "main"),
        _branch("feature_a", "release_base"),
        _branch("feature_b", "feature_a"),
    ]

    plan = build_sync_plan(
        "stack1",
        branches,
        ["feature_a", "feature_b"],
        anchor_branch_name="release_base",
    )

    assert plan.anchor_branch_name == "release_base"
    assert plan.roots == frozenset({"feature_a"})
    assert plan.sync_branches == frozenset({"feature_a", "feature_b"})
    assert "release_base" not in plan.sync_branches


def test_sync_plan_records_anchor_branch_name() -> None:
    branches = [_branch("feature", "main")]
    plan = build_sync_plan("stack1", branches, ["feature"], anchor_branch_name="main")
    assert plan.anchor_branch_name == "main"
```

- [x] **Step 2: Run sync-plan tests and verify RED**

Run:

```bash
rtk uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_plan.py::test_sync_plan_stops_root_resolution_at_tracked_anchor mods/dotfiles/toolbox/stackman/tests/test_sync_plan.py::test_sync_plan_records_anchor_branch_name -q
```

Expected: FAIL because `build_sync_plan` does not accept or store `anchor_branch_name`.

- [x] **Step 3: Implement minimal anchor-aware planning**

Add `anchor_branch_name: str | None` to `SyncPlan`. Pass it through `build_sync_plan`.

Update ancestor walking and root detection so a branch whose parent is `anchor_branch_name` is a root, even if the anchor branch is also tracked.

- [x] **Step 4: Run sync-plan tests and verify GREEN**

Run the same command from Step 2. Expected: PASS.

## Task 4: Sync Resolves Anchor and Uses It for Root Branches

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/store/stacks.py`

- [x] **Step 1: Write failing sync command tests**

Add tests:

```python
def test_sync_dry_run_reports_anchor_and_uses_it_for_root_rebase(git_repo, stackman_db_path) -> None:
    git_repo.checkout_new("release_base", from_ref="main")
    git_repo.commit("release", filename="release.txt", content="release\n")
    git_repo.checkout_new("feature", from_ref="release_base")
    git_repo.commit("feature", filename="feature.txt", content="feature\n")

    db_path = stackman_db_path
    initialize(db_path)
    upsert_branch(
        db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="feature",
        parent_branch_name="main",
        fork_point_sha=git_repo.merge_base("feature", "main"),
    )
    label_branch(
        db_path,
        git_repo.canonical_repo_key(),
        "feature",
        "stack-anchor",
        anchor_branch_name="release_base",
    )

    stdout = io.StringIO()
    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=stdout,
        stderr=io.StringIO(),
    )

    assert app.sync(stack_id="stack-anchor", dry_run=True) == 0
    out = stdout.getvalue()
    assert "[stackman] Anchor branch: 'release_base'" in out
    assert "feature: rebase onto tip of 'release_base'" in out
```

Add an integration test with a real non-main anchor:

```python
def test_sync_rebases_root_branch_onto_non_main_anchor(git_repo, stackman_db_path) -> None:
    git_repo.checkout_new("release_base", from_ref="main")
    git_repo.commit("release 1", filename="release.txt", content="release 1\n")
    git_repo.checkout_new("feature", from_ref="release_base")
    git_repo.commit("feature", filename="feature.txt", content="feature\n")
    fork = git_repo.merge_base("feature", "release_base")

    git_repo.checkout("release_base")
    git_repo.commit("release 2", filename="release2.txt", content="release 2\n")
    release_tip = git_repo.rev_parse("release_base")

    db_path = stackman_db_path
    initialize(db_path)
    upsert_branch(
        db_path,
        repo_root=git_repo.canonical_repo_key(),
        branch_name="feature",
        parent_branch_name="release_base",
        fork_point_sha=fork,
    )
    label_branch(
        db_path,
        git_repo.canonical_repo_key(),
        "feature",
        "stack-anchor",
        anchor_branch_name="release_base",
    )

    app = StackmanApp(
        db_path=stackman_db_path,
        cwd=git_repo.root,
        stdin=io.StringIO(""),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
    )

    assert app.sync(stack_id="stack-anchor") == 0
    git_repo.checkout("feature")
    assert git_repo.merge_base("feature", "release_base") == release_tip
```

- [x] **Step 2: Run sync command tests and verify RED**

Run:

```bash
rtk uv run pytest mods/dotfiles/toolbox/stackman/tests/test_sync_command.py::test_sync_dry_run_reports_anchor_and_uses_it_for_root_rebase mods/dotfiles/toolbox/stackman/tests/test_sync_command.py::test_sync_rebases_root_branch_onto_non_main_anchor -q
```

Expected: FAIL because sync does not print anchors and root branches use recorded parent names only.

- [x] **Step 3: Implement sync anchor resolution**

In `sync.run`:

- Read the stack with `get_stack`.
- Build a preliminary plan using the stored anchor.
- If the stored anchor is missing, infer it from root branch parent names. Persist it only when one non-null parent is shared by all roots.
- Rebuild the plan with the resolved anchor.
- Print the anchor in `_print_plan`.
- For each branch, use `plan.anchor_branch_name` as the target parent name when `branch_name in plan.roots`; otherwise use `record.parent_branch_name`.

- [x] **Step 4: Run sync command tests and verify GREEN**

Run the same command from Step 2. Expected: PASS.

## Task 5: Full Stackman Verification

**Files:**
- Review all modified Stackman files.

- [x] **Step 1: Run focused Stackman test suite**

Run:

```bash
rtk uv run pytest mods/dotfiles/toolbox/stackman/tests -q
```

Expected: all Stackman tests pass.

- [x] **Step 2: Review diff**

Run:

```bash
rtk git diff -- mods/dotfiles/toolbox/stackman docs/superpowers/plans/2026-05-13-stackman-anchor-branch-implementation.md
```

Expected: diff only contains anchor-branch implementation, tests, and this plan.
