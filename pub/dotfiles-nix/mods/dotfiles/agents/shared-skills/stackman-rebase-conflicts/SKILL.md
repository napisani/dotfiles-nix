---
name: stackman-rebase-conflicts
description: Resolve conflicts after Stackman stops during a rebase. Use when stackman sync reports rebase conflicts, when the user asks to continue a Stackman rebase, or when Git is in a conflicted rebase caused by Stackman rebasing a branch onto its parent/upstream branch.
---

# Stackman Rebase Conflicts

## Context

Stackman has rebased the current branch onto its recorded upstream/parent branch. The rebase stopped because incoming changes from that parent branch conflict with commits on the current branch.

Your job is to resolve the conflicts and continue the rebase.

## Workflow

1. Inspect the rebase state and conflicting files:

   ```bash
   git status
   ```

2. Open each conflicted file and resolve conflict markers intentionally:

   ```text
   <<<<<<< HEAD
   incoming parent-branch changes
   =======
   current branch changes being replayed
   >>>>>>> commit-being-replayed
   ```

3. Preserve the intended behavior from both sides when possible. If the correct resolution is ambiguous, ask the user instead of guessing.

4. Stage resolved files:

   ```bash
   git add <resolved-files>
   ```

5. Run the smallest useful verification for the touched area when practical.

6. Finish by continuing the rebase:

   ```bash
   git rebase --continue
   ```

## Important notes

- Do not run `git rebase --abort` unless the user explicitly asks.
- Do not skip commits unless the user explicitly asks.
- Do not commit manually with `git commit`; `git rebase --continue` creates the replayed commit.
- If more conflicts appear after `git rebase --continue`, repeat the workflow until the rebase completes.
