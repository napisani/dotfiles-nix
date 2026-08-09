# Stackman Anchor Branch Design

**Status:** approved for planning  
**Date:** 2026-05-13  
**Scope:** `mods/dotfiles/toolbox/stackman`

## Purpose

Every Stackman stack has a stable anchor branch: the branch that the first stack branch was created from. This is usually `main` or `master`, but it may be any branch name. The anchor is the head/base of the stack, not a Stackman-managed stack branch.

This makes sync behavior explicit. When a sync starts from the top of a stack and no explicit starting branch is supplied, Stackman rebases the first stack branch onto the current tip of the anchor branch. Descendant stack branches continue to rebase onto their recorded parent branch tips.

## Model

Add stack-level metadata:

- `stacks.anchor_branch_name TEXT`

The anchor belongs to the stack id, not to an individual branch. It survives branch reparenting, branch removal, and later changes to which branches carry the stack label.

Existing stacks may have a null anchor until they are touched or migrated. Sync should resolve an anchor before execution, either from stored metadata or from a deterministic backfill based on the current root branch's recorded parent.

## Init Behavior

When `stackman init` creates a new stack id, it stores the chosen parent branch as that stack's anchor.

Examples:

- `feature-a` initialized with parent `main` creates a new stack anchored at `main`.
- `feature-b` initialized with parent `feature-a` inherits `feature-a`'s stack id and keeps the existing anchor unchanged.
- `feature-x` initialized with `--stack custom` and parent `release/1.2` creates stack `custom` anchored at `release/1.2` if `custom` does not already exist.

For explicit `--stack` ids:

- If the stack is new, set its anchor to the selected parent branch.
- If the stack exists with no anchor, fill the anchor from the selected parent branch.
- If the stack already has an anchor, do not change it silently.

Changing an existing stack anchor should be a separate explicit operation later, not an incidental side effect of `init`.

## Sync Behavior

`stackman sync <stack_id>` resolves the stack anchor before planning Git operations.

Default sync behavior:

1. Resolve labeled branches for the stack id.
2. Resolve the sync set from the stored branch dependency tree.
3. Identify the first/root stack branch or branches in topological order.
4. Rebase each root branch onto the current tip of the stack anchor branch.
5. Rebase each descendant branch onto the current tip of its recorded parent branch after that parent has been updated.

The anchor itself is never included in the sync set unless it is separately tracked as an ordinary branch in another stack. A stack does not require the anchor branch to be registered with Stackman.

## Starting Branch

This design leaves room for an explicit starting branch option such as `stackman sync --from <branch>`.

When such an option exists, it should override the default "start at roots from the anchor" behavior. Without that option, sync starts at the top of the stack and uses the anchor as the base for root branches.

## Plan Output

Sync output should make the anchor visible:

```text
[stackman] Stack label: 'sm_example'
[stackman] Anchor branch: 'main'
```

Dry-run output should show root branches rebasing onto the anchor branch tip. Descendant branches should still show their recorded parent branch as the rebase target.

## Backfill for Existing Stacks

For existing stacks with no stored anchor, Stackman should infer the anchor from the current sync roots:

- If all resolved root branches have the same recorded parent branch, use that parent as the anchor.
- If roots disagree or the parent is missing, fail with a message asking the user to set the stack anchor explicitly once such a command exists.

This avoids silently choosing an arbitrary anchor for ambiguous legacy data.

## Testing

Add tests for:

- Stack creation stores an anchor from the first branch's selected parent.
- Child branch init inherits stack labels without changing the anchor.
- Explicit `--stack` creates or fills an anchor but does not overwrite an existing anchor.
- Sync planning exposes the stack anchor.
- Dry-run output reports the anchor and root branch rebase target.
- Integration sync with a non-`main` anchor branch rebases the first stack branch onto that anchor.
- Legacy stacks with a single unambiguous root parent are backfilled or resolved consistently.
- Legacy stacks with ambiguous root parents fail clearly.

## Non-Goals

- Automatically changing a stack's anchor after it has been set.
- Requiring anchor branches to be tracked by Stackman.
- Adding a full anchor management CLI in the first implementation, unless needed to unblock ambiguous legacy data.
