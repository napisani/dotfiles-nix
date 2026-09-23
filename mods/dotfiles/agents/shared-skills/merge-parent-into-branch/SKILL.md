---
name: merge-parent-into-branch
description: Merge the latest direct parent branch into the current branch — trunk (main/master) for a branch cut straight off the trunk, or the immediate parent branch for a stacked PR — resolving conflicts and pushing the merge commit without rewriting history. Use whenever the user says "merge parent into my branch", "back-merge from parent", "update my branch from its parent without rebasing", or otherwise wants the current branch brought up to date with its parent while preserving history.
---

# Merge Parent Into Branch

Merge the current branch's **direct parent** into the branch you are on, resolve
conflicts, and publish the result with a normal push. This is the history-
preserving alternative to `rebase-from-parent`: do not rewrite the current
branch and do not force-push.

## 1. Identify the parent branch

The parent is the branch this one was cut from. Two cases:

- **Direct branch off the trunk** → the parent is the trunk (`main` or `master`).
- **Stacked PR** → the parent is another non-trunk branch that sits between this
  branch and the trunk. Merge from the *immediate* parent, not the trunk.

Never assume it's the trunk. Work it out from the commit graph:

1. **Find the current branch and the trunk.**
   ```sh
   git rev-parse --abbrev-ref HEAD
   git symbolic-ref --short refs/remotes/origin/HEAD
   ```
   If `origin/HEAD` isn't set, fall back to whichever of `origin/main` or
   `origin/master` exists (`git rev-parse --verify`), or ask the user which is
   trunk.

2. **Fetch first**, so parent detection and the merge both use current refs:
   ```sh
   git fetch --all --prune
   ```

3. **Look for a stack parent.** A stack parent is a branch (other than the
   current branch and the trunk) whose tip is an ancestor of `HEAD` and which
   itself carries commits beyond the trunk. Enumerate candidates and check:
   ```sh
   for b in $(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin); do
     git merge-base --is-ancestor "$b" HEAD 2>/dev/null && echo "$b"
   done
   ```
   Among those, the parent is the candidate whose tip is **closest to HEAD**
   (the fewest commits between it and HEAD: `git rev-list --count
   <candidate>..HEAD`). Exclude the current branch and trunk from candidates. If
   the closest remaining branch is the trunk, this is a direct branch.

4. **When it is ambiguous, confirm before touching anything.** Detection can be
   fooled by merged branches, multiple branches at the same commit, or a
   rewritten parent. State the parent you identified and the number of commits
   separating it from `HEAD`, and get confirmation before merging.

Prefer the **remote-tracking** tip of the parent (`origin/<parent>`) when it
exists and is ahead of the local ref — that is the latest parent the user
usually means.

## 2. Merge

Before changing history, verify that the working tree is clean and that you are
still on the intended current branch. Do not silently stash or discard changes.

Merge the parent's up-to-date tip into the current branch:

```sh
git merge --no-edit <parent>       # e.g. git merge --no-edit origin/main
```

A fast-forward is acceptable when the current branch has no commits of its own.
Otherwise, this creates a merge commit that preserves both histories. Do not
use `git rebase`, `git reset`, or any force-push as part of this skill.

If the parent was force-updated or rewritten, stop and explain the history
ambiguity before merging rather than creating a confusing duplicate-history
merge automatically.

## 3. Resolve conflicts

If the merge stops on a conflict, **use the `resolving-merge-conflicts` skill**
to work through it — that skill owns the conflict-resolution methodology
(understanding both sides and resolving correctly). Once the resolution is
complete, continue with:

```sh
git add <resolved-files>
git merge --continue
```

If the user decides not to proceed, abort safely with:

```sh
git merge --abort
```

## 4. Push normally

Once the merge is complete and the working tree is clean, verify before
publishing:

- The branch is where you expect: `git log --oneline --graph -n 20`.
- Nothing is mid-merge: `git status` shows no merge in progress.
- The tests/build still pass if that is cheap and relevant.

Publish with a normal push:

```sh
git push
```

If the push is rejected, do not force-push. Fetch, inspect what changed on the
remote, and re-evaluate the parent and branch state before trying again.

## Guardrails

- This skill preserves history and must not force-push.
- Confirm the parent when detection is uncertain; merging the wrong branch is
  difficult to unwind cleanly.
- Stay on the current branch throughout. Do not modify or push the parent.
- Leave an unresolved merge or an aborted merge clearly reported rather than
  guessing at conflicts or pushing an unverified result.
