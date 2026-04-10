# Stackman Initial Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the first working `stackman` package with a real app boundary, SQLite-backed branch tracking, interactive `init` parent selection via `InquirerPy`, and a real Git/SQLite integration-test harness.

**Architecture:** `stackman` will be a Tier 2 toolbox package under `mods/dotfiles/toolbox/stackman/`. The implementation will center on a `StackmanApp` boundary that accepts injected paths and stdio, with thin modules for Git access, SQLite persistence, and parent selection. Tests will default to real temp Git repos and real temp SQLite files, with small pure unit tests only for deterministic graph logic.

**Tech Stack:** Python 3.12, SQLite (`sqlite3`), `InquirerPy`, `pytest`, real `git` subprocesses

---

### Task 1: Scaffold The Package

**Files:**
- Create: `mods/dotfiles/toolbox/stackman/pyproject.toml`
- Create: `mods/dotfiles/toolbox/stackman/src/stackman/__init__.py`
- Create: `mods/dotfiles/toolbox/stackman/src/stackman/cli.py`
- Create: `mods/dotfiles/toolbox/stackman/src/stackman/app.py`
- Create: `mods/dotfiles/toolbox/stackman/tests/conftest.py`

**Step 1: Write the failing test**

Create a smoke test that imports the package and calls the CLI entrypoint with `["--help"]`.

```python
def test_cli_help_smoke() -> None:
    from stackman.cli import main

    exit_code = main(["--help"])
    assert exit_code == 0
```

**Step 2: Run test to verify it fails**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests -k help_smoke -v`
Expected: FAIL because the package and entrypoint do not exist yet.

**Step 3: Write minimal implementation**

- Add `pyproject.toml` with `stackman = "stackman.cli:main"` entrypoint
- Add empty package modules
- Make `main(argv)` return `0` for `--help`

**Step 4: Run test to verify it passes**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests -k help_smoke -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman
git commit -m "feat: scaffold stackman package"
```

### Task 2: Add The App Boundary

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/cli.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/app.py`
- Create: `mods/dotfiles/toolbox/stackman/tests/test_app.py`

**Step 1: Write the failing test**

Add a test that constructs `StackmanApp` with explicit `db_path`, `cwd`, and stdio buffers.

```python
def test_app_run_uses_injected_environment(tmp_path: Path) -> None:
    stdout = io.StringIO()
    stderr = io.StringIO()
    stdin = io.StringIO("")

    app = StackmanApp(
        db_path=tmp_path / "stackman.db",
        cwd=tmp_path,
        stdin=stdin,
        stdout=stdout,
        stderr=stderr,
    )

    exit_code = app.run(["status"])
    assert exit_code in {0, 1}
```

**Step 2: Run test to verify it fails**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_app.py -v`
Expected: FAIL because `StackmanApp` does not exist yet.

**Step 3: Write minimal implementation**

- Implement `StackmanApp.__init__`
- Implement `StackmanApp.run(argv)`
- Keep CLI as a thin wrapper around real process values

**Step 4: Run test to verify it passes**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_app.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman
git commit -m "feat: add stackman app boundary"
```

### Task 3: Build The Real Git Repo Fixture

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/tests/conftest.py`
- Create: `mods/dotfiles/toolbox/stackman/tests/git_repo_fixture.py`
- Create: `mods/dotfiles/toolbox/stackman/tests/test_git_repo_fixture.py`

**Step 1: Write the failing test**

Add tests for a reusable temp-repo helper that can initialize a repo, configure Git identity, create commits, and create branches.

```python
def test_git_repo_fixture_creates_real_repository(git_repo: GitRepoFixture) -> None:
    assert git_repo.current_branch() == "main"
    sha = git_repo.commit("initial")
    assert len(sha) == 40
```

**Step 2: Run test to verify it fails**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_git_repo_fixture.py -v`
Expected: FAIL because the fixture helper does not exist.

**Step 3: Write minimal implementation**

- Add `GitRepoFixture`
- Run real `git` subprocess commands
- Configure user name and email during fixture setup

**Step 4: Run test to verify it passes**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_git_repo_fixture.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman/tests
git commit -m "test: add real git repo fixture"
```

### Task 4: Add SQLite Schema And Repository Access

**Files:**
- Create: `mods/dotfiles/toolbox/stackman/src/stackman/db.py`
- Create: `mods/dotfiles/toolbox/stackman/src/stackman/models.py`
- Create: `mods/dotfiles/toolbox/stackman/tests/test_db.py`

**Step 1: Write the failing test**

Add a test that initializes the SQLite schema in a temp file and persists a tracked branch row.

```python
def test_db_stores_tracked_branch(tmp_path: Path) -> None:
    db = StackmanDb(tmp_path / "stackman.db")
    db.initialize()
    db.upsert_branch(repo_root="/tmp/repo", branch="feature", parent_branch="main", fork_point_sha="abc123")

    row = db.get_branch("/tmp/repo", "feature")
    assert row.parent_branch_name == "main"
```

**Step 2: Run test to verify it fails**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_db.py -v`
Expected: FAIL because the DB layer does not exist.

**Step 3: Write minimal implementation**

- Create schema bootstrap
- Add basic repo/branch CRUD
- Use real SQLite via `sqlite3`

**Step 4: Run test to verify it passes**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_db.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman
git commit -m "feat: add stackman sqlite storage"
```

### Task 5: Add Deterministic Graph Logic Unit Tests

**Files:**
- Create: `mods/dotfiles/toolbox/stackman/src/stackman/graph.py`
- Create: `mods/dotfiles/toolbox/stackman/tests/test_graph.py`

**Step 1: Write the failing test**

Add unit tests for:

- topological ordering from parent relationships
- sync closure from labeled branches plus descendants

```python
def test_topological_order_parents_before_children() -> None:
    branches = [...]
    assert topological_order(branches) == ["a", "b", "c"]
```

**Step 2: Run test to verify it fails**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_graph.py -v`
Expected: FAIL because graph helpers do not exist.

**Step 3: Write minimal implementation**

- Implement pure functions only
- Keep these tests free of filesystem and Git setup

**Step 4: Run test to verify it passes**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_graph.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman
git commit -m "feat: add stack graph helpers"
```

### Task 6: Implement Git Inspection For `init`

**Files:**
- Create: `mods/dotfiles/toolbox/stackman/src/stackman/git_ops.py`
- Create: `mods/dotfiles/toolbox/stackman/tests/test_git_ops.py`

**Step 1: Write the failing test**

Add tests against a real temp repo for:

- current branch discovery
- repo root discovery
- merge-base calculation
- candidate parent discovery from local branches

```python
def test_candidate_parents_include_trunk_and_overlapping_branches(git_repo: GitRepoFixture) -> None:
    ...
```

**Step 2: Run test to verify it fails**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_git_ops.py -v`
Expected: FAIL because Git inspection helpers do not exist.

**Step 3: Write minimal implementation**

- Wrap real `git` subprocess commands
- Return structured results instead of raw strings where helpful
- Exclude the current branch from candidates
- Always include trunk branches such as `main`/`master` when present

**Step 4: Run test to verify it passes**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_git_ops.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman
git commit -m "feat: add git inspection helpers"
```

### Task 7: Add Parent Selection Adapter With `InquirerPy`

**Files:**
- Create: `mods/dotfiles/toolbox/stackman/src/stackman/prompts.py`
- Create: `mods/dotfiles/toolbox/stackman/tests/test_prompts.py`
- Modify: `mods/dotfiles/toolbox/stackman/pyproject.toml`

**Step 1: Write the failing test**

Add tests for:

- non-TTY ambiguous selection fails with a clear `--parent` message
- prompt choice returns the chosen branch name

```python
def test_ambiguous_parent_requires_parent_in_non_tty(...) -> None:
    ...
```

**Step 2: Run test to verify it fails**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_prompts.py -v`
Expected: FAIL because the prompt adapter does not exist.

**Step 3: Write minimal implementation**

- Add `InquirerPy` dependency
- Implement a small adapter that renders branch name plus metadata
- Keep prompt code isolated from business logic

**Step 4: Run test to verify it passes**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_prompts.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman
git commit -m "feat: add interactive parent selection"
```

### Task 8: Implement `stackman init`

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/app.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/cli.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/db.py`
- Modify: `mods/dotfiles/toolbox/stackman/src/stackman/git_ops.py`
- Create: `mods/dotfiles/toolbox/stackman/tests/test_init_command.py`

**Step 1: Write the failing test**

Cover the first real user flows:

- `stackman init --parent main` stores lineage
- external branch creation requires confirmation
- selected parent is persisted
- stack label remains optional

```python
def test_init_with_explicit_parent_persists_branch_lineage(stackman: StackmanFixture) -> None:
    ...
```

**Step 2: Run test to verify it fails**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_init_command.py -v`
Expected: FAIL because `init` is not implemented.

**Step 3: Write minimal implementation**

- Parse `init` arguments
- Resolve parent via `--parent` or interactive selection
- Compute and store `fork_point`
- Create stack label only when requested

**Step 4: Run test to verify it passes**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_init_command.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman
git commit -m "feat: implement stackman init"
```

### Task 9: Add `StackmanFixture` Integration Helper

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/tests/conftest.py`
- Create: `mods/dotfiles/toolbox/stackman/tests/stackman_fixture.py`
- Create: `mods/dotfiles/toolbox/stackman/tests/test_stackman_fixture.py`

**Step 1: Write the failing test**

Add tests for a reusable fixture that combines temp repo, temp DB, app runner, and DB inspection.

```python
def test_stackman_fixture_runs_commands_and_reads_db(stackman: StackmanFixture) -> None:
    ...
```

**Step 2: Run test to verify it fails**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_stackman_fixture.py -v`
Expected: FAIL because the fixture does not exist.

**Step 3: Write minimal implementation**

- Compose `GitRepoFixture` and `StackmanApp`
- Add `run()`, `tracked_branch()`, and label inspection helpers

**Step 4: Run test to verify it passes**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests/test_stackman_fixture.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman/tests
git commit -m "test: add stackman integration fixture"
```

### Task 10: Verify The First Implementation Slice End-To-End

**Files:**
- Modify: `mods/dotfiles/toolbox/stackman/docs/design.md`
- Create: `mods/dotfiles/toolbox/stackman/README.md`

**Step 1: Write the failing test**

Add one subprocess CLI test that exercises a real temp repo and temp DB through the installed entrypoint.

```python
def test_cli_init_with_parent_flag_subprocess(...) -> None:
    ...
```

**Step 2: Run test to verify it fails**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests -k subprocess -v`
Expected: FAIL until the entrypoint wiring is complete.

**Step 3: Write minimal implementation**

- Finish any entrypoint or packaging gaps
- Add a small `README.md` with local usage and test commands
- Update `design.md` if implementation decisions sharpen wording

**Step 4: Run test to verify it passes**

Run: `uv run --with pytest pytest mods/dotfiles/toolbox/stackman/tests -v`
Expected: PASS for the full initial test suite

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/stackman docs/plans/2026-04-10-stackman-initial-implementation.md
git commit -m "feat: ship initial stackman implementation slice"
```
