# stackman — design

**Status:** draft  
**Location in repo:** `mods/dotfiles/toolbox/stackman/` (Tier 2 toolbox package when implemented)

## Purpose

`stackman` (stack manager) is a CLI for **stacked pull requests**: many branches built on top of each other (or fanning out from a shared parent) in one Git repo. It records enough metadata to **rebase the right branches in the right order** after upstream moves, without interactive `fzf` pickers for fork points.

It complements normal Git workflows: you still run `git checkout -b …`; `stackman` tracks relationships and automates **sync** across the resulting tree.

## Core model

`stackman` fundamentally tracks a **branch dependency tree**, not a set of user-declared stack ids.

- The canonical data for a tracked branch is: **repo**, **branch name**, **parent branch**, and **fork point**.
- A **stack id** is secondary metadata used to name or select a slice of that tree.
- v1 is explicitly **local-machine-only**. Metadata does not need to survive fresh clones or be shared across machines yet.

## Goals

- **Init from a branch:** After creating a new branch, register it with a known **parent branch** and **fork point** (the commit analogous to “the commit before the first commit on this branch”).
- **Global database:** One SQLite database under the XDG data directory — **not** hand-edited; inspection via SQLite CLI or future `stackman doctor` / export commands.
- **Optional stack labels:** A **stack id** is an optional organizational label, not the primary identity of a branch relationship. Multiple labels can apply to overlapping sets of branches.
- **Sync propagates downstream:** Syncing one label must update **every tracked branch that depends (transitively) on branches that move** — including branches only tagged with a different stack id when they share the same tree under a common root (see [Graph model](#graph-model)).
- **Predictable Git operations:** Sync uses normal `git rebase` semantics; the user resolves conflicts with the usual `git rebase --continue` / `--abort` workflow. After history rewrites, pushes should use **`--force-with-lease`** (with clear messaging).

## Non-goals (initially)

- Replacing Git hosting PR UIs or APIs (GitHub/GitLab stacked PR features).
- Handling arbitrary merge-heavy DAGs without a single parent per branch; **one parent branch per tracked branch** is the baseline (merge-heavy flows may need explicit follow-up design).
- Storing stack state inside the repo tree (e.g. committed JSON) — v1 uses only the global SQLite DB.

## Storage

| Item | Path / mechanism |
|------|------------------|
| Database directory | `$XDG_DATA_HOME/stackman/`, i.e. `~/.local/share/stackman/` when `XDG_DATA_HOME` is unset |
| Database file | e.g. `~/.local/share/stackman/stackman.db` |
| Optional non-canonical data | If needed later: `~/.local/state/stackman/` for logs, caches, or session hints — **not** the source of truth |

SQLite is required: relational queries (branches per repo, children of a parent, branches carrying a label) and transactional updates. Python’s stdlib `sqlite3` avoids extra dependencies.

## Graph model

### Canonical structure

Per **repository** (keyed by absolute `git rev-parse --show-toplevel`, normalized), `stackman` maintains a **tree** of tracked branches:

- Each tracked **branch** has exactly one **`parent_branch`** (the branch it was created from for stacking purposes) and a **`fork_point`** commit (the parent of the first commit unique to this branch along that parent line — the same notion as selecting “the commit before the first commit” in a manual `git rebase --onto` flow).

- Multiple **children** may share a parent (e.g. `branch_b` → `branch_c` and `branch_b` → `branch_z`).

### Stack ids as labels

- A **stack id** identifies a **named slice** of work (e.g. `stack1`, `stack2`), but it is **not** required to define the actual branch lineage.
- Association is **many-to-many**: branches ↔ stack labels (join table).
- **Sync is not limited to rows that share a label.** Labels determine **where the user starts**; **sync closure** is defined by the **dependency tree** (see below).
- A branch may be tracked with **no explicit stack label** if the user does not care about naming that slice yet.

### Parent detection vs. source of truth

`stackman` should distinguish between:

- **Canonical lineage**: the stored `parent_branch` and `fork_point`
- **Parent selection inputs**: explicit user input, branch-creation context, and overlap-based candidate discovery

For v1, `stackman` should avoid silent heuristics when recording lineage:

- If the user explicitly passes `--parent`, that value wins.
- If a future `stackman` command creates the branch itself, it should record the current branch as the parent at creation time.
- If the user created the branch outside `stackman` (for example via `git checkout -b ...`) and later runs `stackman init`, `stackman` should discover plausible parent candidates from commit overlap and ask the user to choose interactively.
- Commit overlap is therefore used to build a **candidate set**, not to silently choose a parent.

This keeps sync deterministic: once a branch is registered, future operations rely on stored metadata rather than re-deriving intent from Git history each time.

### Ambiguity example

Consider two independent branches created from the same point on `main`:

```text
main <- branch_a <- branch_b
main <- branch_c <- branch_d
```

`branch_a` and `branch_c` may have the same overlap with `main`, but they are still separate lineages.

When the user later runs `stackman init` on `branch_c`, `stackman` must not silently associate it with `branch_a`'s stack. Instead, it should:

1. identify the plausible parent candidates
2. present them interactively
3. store the user's explicit choice as `parent_branch`

Sharing a fork point or merge-base with another branch is not sufficient to imply stack membership.

### Example

```
stack1: branch_a ← branch_b ← branch_c
stack2: branch_b ← branch_z
```

Here `branch_z` is only labeled `stack2`, but it **depends on** `branch_b`. Rebuilding `branch_b` during `stackman sync stack1` changes the tip `branch_z` must base on, so **syncing `stack1` must also update `branch_z`** (and any other descendants of the affected subtree).

## Sync closure and order

### Inputs

- User runs e.g. `stackman sync <stack_id>`.

### Resolution

1. **Labeled set `L`** — all branches that have label `<stack_id>`.
2. **Roots** — walk each branch in `L` along `parent_branch` until reaching a **trunk** branch (e.g. `main`) or a branch not tracked by `stackman`. The **minimal roots** spanning `L` define the top of the subtree to consider.
3. **Sync set `S`** — all **tracked** branches in this repo that are **descendants** of those roots (full subtree under the resolved root(s), in the stored tree). This includes branches labeled only with other stack ids if they sit under the same subtree.
4. **Order** — **topological** order from root toward leaves (parents before children). Siblings (e.g. `branch_c` and `branch_z` after `branch_b`) may run in any order **after** their parent, as long as all dependencies are satisfied.

### Branch-first implication

Because lineage is primary and labels are secondary, the system should be designed so commands can eventually operate from either:

- a **stack id** (`stackman sync stack1`)
- a **branch selector** (`stackman sync --from branch_b`)

Even if v1 exposes the stack-id form first, the underlying model should not assume labels are mandatory.

### Optional behavior (later)

- **`sync --only-labeled`:** Restrict `S` to branches that carry the given label only — **different semantics** from default and must be explicit to avoid surprising skips of sibling branches.

## Sync algorithm (per branch)

High level for each branch `B` in order (after checking out `B`):

1. Determine **new upstream tip** — the current tip of `B`’s recorded `parent_branch` (after prior steps have updated the parent if needed).
2. Run an appropriate **rebase** using the stored **`fork_point`** so that unique commits replay on top of the new parent tip (equivalent in spirit to `git rebase --onto` with a known old fork boundary — exact Git incantation is an implementation detail).
3. On conflict: stop; user uses standard Git rebase resolution; optional future `stackman sync --continue` could resume.
4. **Push** with **`git push --force-with-lease`** (and documented safety caveats) when updating remote branches that were rebased.

Before starting, **remember the current branch** and restore it when sync finishes or aborts (including failures).

## SQLite schema (directional)

Exact names may change during implementation; relationships matter more than column names.

- **`repos`** — `id`, absolute root path (normalized), maybe `created_at`.
- **`branches`** — `id`, `repo_id`, branch name, `parent_branch_name` (or `parent_id`), `fork_point_sha`, uniqueness on `(repo_id, branch_name)`.
- **`stacks`** — `id` (text uuid or slug), human-readable name optional, `created_at`.
- **`branch_stack_labels`** — `branch_id`, `stack_id` (many-to-many).

Indexes for: `repo_id` + `parent_branch_name` (children lookup); `stack_id` (branches for a label); `repo_id` + `branch_name` (fast lookup by name).

## CLI sketch (non-exhaustive)

| Command | Role |
|---------|------|
| `stackman init` | Register current branch (in repo) with parent + fork point; optionally assign or create stack label(s). |
| `stackman sync <stack_id>` | Resolve sync set `S`, topological rebase + push sequence as above. |
| `stackman status` | Show current branch’s place in the tree / labels (later). |
| `stackman doctor` | DB path, repo match, clean worktree hints (later). |

Exact flags (`--repo`, dry-run, etc.) belong in an implementation plan.

### `init` behavior sketch

`stackman init` should prioritize recording correct lineage over collecting labels:

1. Determine the current repo and current branch.
2. Resolve `parent_branch` using one of these flows:
   - explicit `--parent`
   - recorded creation context from a future `stackman` branch-creation command
   - interactive selection from overlap-derived parent candidates when the branch was created outside `stackman`
3. Refuse to silently pick a parent from ambiguous history.
4. Compute and store the `fork_point` against that chosen parent.
5. Optionally attach one or more stack labels.

This means the user does **not** need to provide a stack id just to make the branch trackable.

## Toolbox integration

Per `mods/dotfiles/toolbox/README.md`, `stackman` is a **Tier 2** package: `toolbox/stackman/pyproject.toml`, `src/stackman/`, entry point `stackman = …`. Home-manager `uvx` discovery installs editable tools under `~/.local/bin`.

## Testing and safety

- Treat **real Git + real SQLite integration tests** as the primary testing layer.
- Document that **sync rewrites history** on branches that were rebased; teammates must coordinate.
- Consider **dry-run** mode (`sync --dry-run`) listing branches and planned operations before execution.

## Testing strategy

### Testing philosophy

`stackman` should be tested as close to real usage as possible:

- Use a **real SQLite database file**
- Use a **real Git repository on disk**
- Use **real subprocess Git commands**
- Avoid mocking Git, SQLite, or the filesystem

The main test seam should be **environment injection**, not behavioral mocking.

### What to inject

The implementation should be structured so tests can pass explicit runtime parameters instead of relying on global process state:

- `db_path`
- `repo_root` or `cwd`
- XDG data/state directories when needed
- `stdin` / `stdout` / `stderr` streams for interactive flows

That suggests an application boundary shaped roughly like:

```python
StackmanApp(
    db_path=...,
    cwd=...,
    stdin=...,
    stdout=...,
    stderr=...,
)
```

This keeps production behavior real while letting tests run hermetically in temporary directories.

### Test isolation

Tests should be **isolated per test case**, not per suite:

- each test gets its own temp repo
- each test gets its own temp SQLite file
- each test sets up only the branch topology it needs

This keeps cases easy to reason about and avoids hidden coupling across tests.

To reduce boilerplate, the test code should provide reusable helpers/fixtures for:

- creating a temp repo
- making commits with predictable content
- creating branches from named parents
- initializing `stackman` tracking state
- reading current DB contents
- asserting branch tips / ancestry relationships

The fixture code should be **DRY and reusable**, while the repo and DB instances remain **fresh per test**.

### Test layers

#### Pure unit tests

Keep a small number of pure unit tests for deterministic logic that does not need Git:

- topological ordering from stored parent relationships
- sync-set closure from labels plus branch tree shape
- validation / normalization helpers

These should stay lightweight and avoid filesystem setup.

#### Integration tests (primary)

Most behavior should be covered by integration tests using temp directories:

- create a real repo in a temp directory
- create commits and branches using real Git
- point `stackman` at a temp SQLite file
- run the actual application logic or CLI entrypoints
- assert on both Git state and DB state

Representative scenarios:

- linear stack: `main <- a <- b <- c`
- forked stack: `main <- a <- b`, then `b <- c` and `b <- z`
- parallel roots: `main <- a <- b` and `main <- c <- d`
- sync propagation into descendants outside the requested label
- unrelated parallel branches not included in sync
- branch restoration after sync success/failure
- init on a branch created outside `stackman`, requiring interactive parent selection

#### CLI tests

Add a smaller number of subprocess-style CLI tests to verify:

- argument parsing
- user-facing prompts
- interactive parent selection
- exit codes and error messages

These should sit on top of the same temp repo/temp DB harness rather than inventing a separate testing model.

### Interactive testing

Because `stackman init` may require interactive parent disambiguation, the app layer should allow tests to provide scripted input and capture output.

Tests should verify that:

- candidate parents are presented clearly
- ambiguous cases do not silently choose a parent
- the selected parent is what gets stored

For interactive selection, v1 should use **`InquirerPy`** rather than building a custom prompt layer. This gives `stackman` a standard terminal selection UI while keeping the selection behavior easy to reason about.

### Safety invariants to assert

Tests should focus on a few core guarantees:

- recorded `parent_branch` and `fork_point` match the user's chosen lineage
- sync walks the correct descendant closure
- unrelated stacks are not pulled in just because they share a merge-base
- operations happen in parent-before-child order
- failure paths preserve enough state to inspect or resume safely
- the original checked-out branch is restored after sync completes or aborts

### Proposed test harness API

The implementation should expose a small application boundary that is easy to call from tests without patching global state:

```python
from pathlib import Path
from typing import TextIO


class StackmanApp:
    def __init__(
        self,
        *,
        db_path: Path,
        cwd: Path,
        stdin: TextIO,
        stdout: TextIO,
        stderr: TextIO,
    ) -> None: ...

    def run(self, argv: list[str]) -> int: ...
```

Design intent:

- `db_path` controls where SQLite lives
- `cwd` determines which repo the app is operating on
- `stdin` / `stdout` / `stderr` make prompts and output testable
- `run(argv)` gives tests a simple way to exercise commands without spawning a subprocess unless they specifically want CLI coverage

The top-level CLI entrypoint can then be a thin wrapper that wires real process values into `StackmanApp`.

Interactive commands may internally delegate to an adapter around `InquirerPy`, but that adapter should remain behind the app boundary so tests can exercise the surrounding behavior without patching broad global state.

### Reusable test fixtures

The test suite should provide a reusable fixture layer above temp directories.

Suggested fixtures/helpers:

```python
class GitRepoFixture:
    root: Path

    def git(self, *args: str) -> str: ...
    def commit(self, message: str, *, filename: str | None = None, content: str | None = None) -> str: ...
    def checkout_new(self, branch: str, *, from_ref: str = "HEAD") -> None: ...
    def current_branch(self) -> str: ...
    def rev_parse(self, ref: str) -> str: ...


class StackmanFixture:
    repo: GitRepoFixture
    db_path: Path

    def app(self, *, stdin=None, stdout=None, stderr=None) -> StackmanApp: ...
    def run(self, *argv: str, stdin_text: str = "") -> tuple[int, str, str]: ...
    def tracked_branch(self, branch: str) -> dict: ...
    def branch_labels(self, branch: str) -> list[str]: ...
```

Responsibilities:

- `GitRepoFixture` owns real Git operations and hides setup noise
- `StackmanFixture` owns app construction, command execution, and DB inspection helpers
- tests read clearly without repeating repo/bootstrap code

### Fixture setup rules

Each test should create its own isolated fixture set:

1. create temp directory
2. initialize repo
3. configure minimal Git identity
4. create initial `main` commit
5. create temp DB path
6. construct `StackmanFixture`

That setup should live in shared pytest fixtures/factory helpers, but the resulting repo and DB should remain unique per test.

### Example test shapes

#### Direct app-level test

This should be the default way to test behavior:

```python
def test_init_requires_parent_selection_for_ambiguous_overlap(stackman: StackmanFixture):
    repo = stackman.repo
    repo.checkout_new("branch_a", from_ref="main")
    repo.commit("a1")
    repo.checkout_new("branch_c", from_ref="main")
    repo.commit("c1")

    exit_code, stdout, stderr = stackman.run("init", stdin_text="1\n")

    assert exit_code == 0
    assert "Select parent branch" in stdout
    assert stackman.tracked_branch("branch_c")["parent_branch_name"] == "main"
```

#### Sync topology test

```python
def test_sync_includes_descendants_outside_requested_label(stackman: StackmanFixture):
    ...
```

These tests should assert both:

- Git state after the command
- persisted DB state after the command

#### Subprocess CLI test

Reserve subprocess tests for true CLI concerns:

- shell-facing exit codes
- real argv parsing
- TTY/non-TTY behavior differences

They should still reuse the same temp repo/temp DB arrangement.

### Non-TTY behavior

Interactive selection implies a non-interactive fallback must be specified.

Recommended rule:

- if parent selection is ambiguous and `stdin` is not interactive, `stackman init` should fail with a clear message requiring `--parent`

This should be covered by tests directly at the app layer and at the subprocess CLI layer.

### Parent selection UX

When `stackman init` finds multiple plausible parents for a branch created outside `stackman`, it should present them using **`InquirerPy`**.

Candidate selection policy:

1. start from **local branches only**
2. exclude the current branch
3. include branches whose history has meaningful overlap with the current branch
4. always include configured trunk branches such as `main` or `master` when present
5. if no candidates remain, fail and require `--parent`

For branches created outside `stackman`, v1 should **always require explicit confirmation of the parent**, even if only one plausible candidate exists. This keeps the UX consistent and avoids silent assumptions about lineage.

Recommended behavior:

- show a short explanation of why parent selection is required
- list candidate parent branches in a selectable prompt
- show the **branch name plus pertinent metadata** for each candidate so the user can distinguish similar histories
- return the chosen branch name as the canonical `parent_branch`

Pertinent metadata may include:

- merge-base / fork-point short SHA
- relative commit distance between the candidate and the current branch
- whether the candidate is `main` / trunk
- whether the candidate is already tracked by `stackman`

Example shape:

```text
Ambiguous parent branch for current branch `branch_c`.
Select the branch this work was based on:

> main      merge-base: abc1234  trunk
  branch_a  merge-base: abc1234  tracked  ahead: 1 / behind: 0
  branch_b  merge-base: def5678  tracked  ahead: 3 / behind: 0
```

The branch name should remain the primary identifier in the UI; metadata is supporting context rather than the canonical value.

If no TTY is available, `InquirerPy` should not be invoked; the command should fail fast and require `--parent`.

## References (conceptual)

- Existing helper: `git-rebase-onto` in `mods/dotfiles/.bashrc.d/0070_git.bashrc` — interactive fork selection; `stackman` automates the same fork notion from stored metadata.
- XDG base directories: data under `~/.local/share` for durable application data.
