# stackman — design

**Status:** implemented / evolving  
**Location:** `mods/dotfiles/toolbox/stackman/`

## Purpose

`stackman` is a small CLI for local stacked-branch workflows. It tracks branch lineage in a SQLite database so a full stack can be rebased in the right order after an upstream branch moves.

It complements normal Git usage: you still create branches with Git, resolve conflicts with Git, and push with Git. Stackman records enough metadata to make repeated stack syncs predictable.

## User-facing CLI

The CLI is branch-first. Commands can be run from any worktree in the repository; the current branch is only a default selector.

```bash
stackman                         # show current branch tracking status
stackman track [BRANCH] --parent PARENT
stackman chain ANCHOR BRANCH...
stackman sync [BRANCH] [--allow-dirty]
stackman done [BRANCH]
stackman list
stackman forget [BRANCH]
stackman discover PR_NUMBER [--apply]
```

### Command semantics

| Command | Role |
|---------|------|
| `stackman` | Show tracking state for the current branch. |
| `stackman track [BRANCH] --parent PARENT` | Register or update one branch with its parent and fork point. `BRANCH` defaults to the current branch. |
| `stackman chain ANCHOR BRANCH...` | Register an existing linear stack. `ANCHOR` is not tracked; every later branch points at the previous item. |
| `stackman sync [BRANCH]` | Sync the full stack containing `BRANCH`; `BRANCH` defaults to the current branch. |
| `stackman done [BRANCH]` | Mark a branch as done: remove it from Stackman tracking and reparent its children onto its recorded parent. Does not delete Git branches. |
| `stackman list` | List tracked branches in the current repository. |
| `stackman forget [BRANCH]` | Stop tracking a branch without reparenting children. Does not delete Git branches. |
| `stackman discover PR_NUMBER [--apply]` | Use `gh` to discover an open PR stack from a PR number. Read-only by default; `--apply` imports local branches into Stackman. |

## Core model

Stackman tracks a branch dependency tree per Git repository.

The canonical tracked-branch fields are:

- repository key
- branch name
- parent branch name
- fork-point SHA

A stack label is internal metadata used to find the full stack containing a selected branch. Users do not manage stack labels directly. `track` creates a new opaque stack label for a root branch; child branches inherit their tracked parent's label. `chain` creates one opaque label for the whole chain.

Repository identity uses `git rev-parse --git-common-dir`, so linked worktrees for one clone share the same Stackman metadata.

## Tracking

### `track`

`stackman track [BRANCH] --parent PARENT`:

1. Resolve the repository from `--repo` or the current directory.
2. Use `BRANCH` or the current branch.
3. Validate both `BRANCH` and `PARENT` exist locally.
4. Store `parent_branch_name = PARENT`.
5. Store `fork_point_sha = git merge-base BRANCH PARENT`.
6. Replace any previous internal stack metadata for `BRANCH`.
7. If `PARENT` is tracked and has a stack label, inherit that label.
8. Otherwise create a new opaque stack label anchored at `PARENT`.

### `chain`

`stackman chain ANCHOR BRANCH...` is the batch form for an existing linear stack.

For example:

```bash
stackman chain main feature-a feature-b feature-c
```

records:

```text
feature-a -> main
feature-b -> feature-a
feature-c -> feature-b
```

and applies one new opaque stack label to all tracked branches in the chain.

## Sync

`stackman sync [BRANCH]` uses `BRANCH` only as the selector. It syncs the full stack containing that branch.

Resolution:

1. Find the selected branch's single stack label.
2. Find all branches in the current repo carrying that label.
3. Walk upward through stored parents to find the stack root(s), stopping at the stack anchor, an untracked parent, or a trunk branch.
4. Include all tracked descendants below those roots, even descendants without the selected label.
5. Rebase in topological order: parents before children.

Per branch:

1. Determine the current tip of the branch's sync parent.
2. Optionally squash post-fork commits when `--squash` is passed.
3. Run `git rebase --onto <parent-tip> <stored-fork-point>`.
4. If a conflict occurs, keep Stackman running while the user resolves with `git rebase --continue` or aborts with `git rebase --abort`.
5. After a successful rebase, update `fork_point_sha` to the parent tip used for that rebase.
6. Push with `--force-with-lease` when the branch has an upstream.

Before a non-dry-run sync, Stackman checks only worktrees involved in the sync set. Unrelated linked worktrees may be dirty. `--allow-dirty` skips this preflight and lets Git decide whether checkout/rebase can proceed; it is intentionally incompatible with `--squash`.

## Done vs forget

`done` and `forget` both remove Stackman metadata for a branch, but they mean different things:

- `done BRANCH`: branch was merged or is no longer part of the stack. Children are lifted onto `BRANCH`'s recorded parent.
- `forget BRANCH`: stop tracking this branch only. Children are not reparented and may still record the forgotten branch as parent.

Neither command deletes Git branches.

## Discovering existing PR stacks

`stackman discover PR_NUMBER` is the only GitHub-specific command. It shells out to `gh` to read open PR `headRefName` / `baseRefName` metadata; the rest of Stackman remains Git-provider agnostic.

Discovery starts from the required PR number, walks upward through PR base branches until it reaches a non-PR anchor branch, then traverses the selected stack subtree downward. By default it only prints the tree and equivalent `stackman track` plan. `--apply` writes tracking metadata for branches that already exist locally and skips missing local branches without fetching or deleting anything.

## Storage

| Item | Path / mechanism |
|------|------------------|
| Database directory | `$XDG_DATA_HOME/stackman/`, or `~/.local/share/stackman/` when unset |
| Database file | `stackman.db` |

SQLite schema:

- `repos` — canonical repository key
- `branches` — tracked branch lineage and fork point
- `stacks` — internal opaque stack labels and their anchor branch
- `branch_stack_labels` — branch-to-stack-label join table

## Testing strategy

Tests should stay close to real usage:

- real Git repositories on disk
- real linked worktrees where relevant
- real SQLite database files
- subprocess Git commands rather than mocks
- injectable app boundary for `db_path`, `cwd`, `stdin`, `stdout`, and `stderr`

The test suite should exercise the public branch-first interface (`track`, `chain`, `sync`, `done`, `list`, `forget`) while still validating persistence and graph behavior through the store where useful.
