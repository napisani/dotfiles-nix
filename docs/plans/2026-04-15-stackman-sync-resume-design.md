# Stackman Sync Resume Design

**Date:** 2026-04-15

**Goal:** Fix `stackman sync` so repeated runs do not replay already-rebased parent commits into descendant branches, and keep the command attached to the user through conflict resolution until the stack can continue or abort cleanly.

## Problem

`stackman sync` currently rebases each tracked branch using the stored `fork_point_sha`, but it does not advance that stored fork-point after a successful rebase. On a later sync run, Stackman still uses the original historical fork-point, so the branch can replay commits that were already incorporated on earlier runs. In stacked branches, that produces duplicated history and noisy conflict resolution.

The current conflict behavior also exits immediately after a rebase stops for conflicts. That forces the user to resolve conflicts manually and then invoke `stackman sync` again, which compounds the stale fork-point problem and breaks the intended flow.

## Requirements

- Preserve the existing sync model: for each branch, rebase onto the current parent tip using the stored fork-point as the upstream boundary.
- Do not change stack membership, parent selection, or sync ordering semantics.
- After a successful rebase, update the tracked branch metadata so future sync runs know the branch is already aligned to the parent tip used for that rebase.
- If a rebase conflicts, pause `stackman sync`, let the user resolve conflicts with normal git commands, and continue the same sync session when the user presses Enter.
- If the paused rebase is aborted, exit `stackman sync` with a non-zero status and stop immediately.
- Never update metadata for an incomplete or aborted rebase.

## Chosen Approach

Keep the current `git rebase --onto <parent_tip> <stored_fork_point>` operation and make two behavioral changes:

1. Treat the parent tip used for a successful rebase as the branch's new canonical `fork_point_sha`.
2. Replace the current conflict exit path with an interactive wait loop that keeps the sync command running until the rebase completes or is aborted.

This keeps Stackman's mental model intact. The database remains the source of truth for stack lineage, but successful sync operations now refresh that lineage so later runs do not replay old base history.

## Sync Flow

For each branch in sync order:

1. Resolve the current parent branch from tracked metadata.
2. Resolve the parent's current tip SHA.
3. Compare the branch's stored `fork_point_sha` with the current parent tip.
4. If they match, skip the branch because it is already synced to the current parent base.
5. Otherwise, run `git rebase --onto <parent_tip> <stored_fork_point>` in the correct worktree.
6. If the rebase succeeds, persist `fork_point_sha = <parent_tip>` for that branch and continue.
7. If the rebase stops for conflicts, print guidance and enter a wait loop.
8. In the wait loop, prompt the user to press Enter after resolving the rebase state.
9. After Enter:
   - If a rebase is still in progress, tell the user it is still active and keep waiting.
   - If the rebase is complete, persist `fork_point_sha = <parent_tip>` for that branch and continue syncing remaining branches.
   - If the rebase was aborted, return a non-zero exit code and stop the sync run.

## State Model

The stored `fork_point_sha` becomes "the parent tip this branch was last successfully synced onto" rather than "the branch's original fork point forever." That is the correct invariant for Stackman's sync behavior because the rebase operation rewrites the branch history relative to the latest parent tip.

This does not change how branch parentage is modeled. `parent_branch_name` remains stable unless explicitly changed elsewhere. Only the boundary SHA used by sync advances.

## Failure Handling

- Dirty worktree checks still happen before sync begins.
- Rebase conflicts remain user-resolved via native git commands.
- Metadata writes happen only after Stackman can prove the rebase completed.
- Aborted rebase means the stack is left partially synced, and Stackman exits non-zero without trying to continue descendant branches.

## Testing Strategy

Add coverage for:

- A repeated sync run where a branch was already rebased successfully and should be skipped on the second run.
- A descendant branch that previously duplicated history due to stale fork-point metadata.
- The conflict wait loop:
  - continue path where the user completes the rebase and Stackman resumes
  - abort path where Stackman exits non-zero
  - still-in-progress path where Stackman keeps waiting

## Affected Areas

- `mods/dotfiles/toolbox/stackman/src/stackman/commands/sync.py`
- `mods/dotfiles/toolbox/stackman/src/stackman/store/branches.py` or the relevant store module for tracked branch updates
- `mods/dotfiles/toolbox/stackman/tests/test_sync_command.py`
- Potentially `mods/dotfiles/toolbox/stackman/tests/test_app.py` if the interactive prompt needs app-level coverage

## Non-Goals

- No change to how stack roots are resolved.
- No automatic conflict resolution.
- No attempt to continue syncing descendants after an aborted rebase.
- No redesign of Stackman's broader architecture beyond what is needed for this sync fix.
