# Stackman Sync History Tests Design

Date: 2026-04-18

## Goal

Add real end-to-end `stackman sync` regression tests that verify sync rewrites only the intended ancestry in stacked branches while preserving the branch-local history that should survive a rebase.

The new coverage should use the existing temporary git repository fixture and real git operations, not mocks or patched git helpers.

## Requirements

- Use the existing stackman test git setup in `mods/dotfiles/toolbox/stackman/tests/`.
- Exercise `StackmanApp.sync(...)` end-to-end against a real temporary git repository.
- Do not use mocks for git behavior.
- Verify rewritten ancestry by SHA where the parent history should be adopted exactly.
- Verify preserved branch-local history by commit count and commit messages.
- Add coverage for these three cases:

1. syncing a stack with `2+` branch-local commits retains the history after the fork-point while replacing the fork-point and older ancestry with the current parent-tip history
2. when a commit is added to the middle branch of a three-branch stack, `stackman sync` rebases only the tail branch
3. when a commit is added to the first branch of a three-branch stack, `stackman sync` rebases branches 2 and 3, and a second sync immediately after that is a full no-op

## Recommended Approach

Add three focused tests to `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`.

Each test should:

1. create a real branch stack with the existing `GitRepoFixture`
2. register stack metadata in the sqlite-backed store
3. record the relevant pre-sync branch tips and history slices
4. make the parent-side change that should trigger sync
5. run `StackmanApp.sync(...)`
6. assert exact ancestry and post-fork history expectations with real git commands

This keeps the new coverage aligned with the existing stackman sync suite, which already tests real git rebases, worktrees, and conflict handling in `test_sync_command.py`.

## Test Design

### Case 1: Preserve post-fork history while replacing older ancestry

Create a stack where a child branch has at least two commits after its stored fork-point.

Suggested shape:

1. create `branch1` from `main`
2. create `branch2` from `branch1`
3. add `2+` commits on `branch2`
4. register `branch1 -> main` and `branch2 -> branch1`
5. advance `branch1` with a new commit
6. run sync for the stack label rooted at `branch1`

Assertions after sync:

- the commits in `branch2` after the new fork-point have the same count as before sync
- those preserved commits have the same commit messages in the same order as before sync
- the stored fork-point for `branch2` advances to the pre-rebase tip of `branch1`
- from that new fork-point backward, `branch2` and `branch1` share the exact same SHA ancestry

The intent is to prove the rebase replayed only the child-local commits and replaced only the inherited base history.

### Case 2: Middle-branch edit rebases only the tail branch

Create a three-branch stack `branch1 -> branch2 -> branch3` with tracked metadata for all three branches.

Then:

1. record tip SHAs for all three branches
2. add a new commit to `branch2`
3. run sync

Assertions after sync:

- `branch1` tip SHA is unchanged
- `branch2` tip SHA reflects only the manual new commit and is not rewritten by sync
- `branch3` tip SHA changes because it is rebased onto the new `branch2` tip
- the new fork-point and older ancestry of `branch3` exactly match `branch2` by SHA
- the branch-local history on `branch3` after its new fork-point keeps the same commit count and commit messages as before sync

This proves sync propagates only to descendants of the changed branch.

### Case 3: Root-branch edit rebases the tail, then second sync is a no-op

Create the same three-branch stack `branch1 -> branch2 -> branch3`.

Then:

1. record tip SHAs for all three branches before any parent change
2. add a new commit to `branch1`
3. run sync once
4. record the resulting tip SHAs for all three branches
5. run sync a second time without further git changes

Assertions after the first sync:

- `branch1` tip SHA is the manual new tip
- `branch2` tip SHA changes because it is rebased onto the new `branch1` tip
- `branch3` tip SHA changes because it is rebased after `branch2`
- the ancestry from the new fork-point backward matches the respective parent by exact SHA for both `branch2` and `branch3`
- the post-fork history for `branch2` and `branch3` preserves commit count and commit messages

Assertions after the second sync:

- `branch1`, `branch2`, and `branch3` all keep the exact same tip SHA they had after the first sync
- the output includes the existing already-synced skip messaging for rebased branches where applicable

This proves fork-point advancement prevents repeated rewriting once the stack is aligned.

## Assertion Helpers

Keep helper logic minimal and local to `test_sync_command.py` unless duplication becomes noisy.

Useful patterns:

- collect commit messages for a range with `git log --reverse --format=%s <range>`
- count commits in a range with `git rev-list --count <range>`
- compare inherited ancestry by walking first-parent or full ancestry from the expected fork-point backward with `rev-list`

The tests should prefer simple inline helpers for:

- post-fork commit message lists
- post-fork commit counts
- ancestry SHA slices shared by parent and child from the new fork-point backward

## File Scope

- Modify: `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`

No production code changes are expected if the current sync behavior already satisfies these invariants. If a test exposes a real bug, the follow-up implementation should stay narrowly focused on the failing sync behavior.

## Success Criteria

The work is complete when:

- `test_sync_command.py` includes three new real-git sync regression tests for the requested scenarios
- the tests verify preserved branch-local history by commit count and commit message order
- the tests verify inherited base history by exact SHA ancestry
- the second sync in the root-branch-change scenario is proven to be a no-op by unchanged branch tip SHAs
- the targeted stackman sync test suite passes

## Non-Goals

- adding mock-based unit tests for git behavior
- changing stack membership, sync ordering, or branch-parent semantics
- refactoring the stackman test fixture unless the new coverage exposes a concrete limitation
