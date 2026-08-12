---
name: rebase-from-parent
description: Rebase the current branch onto its direct parent — trunk (main/master) for a branch cut straight off the trunk, or the immediate parent branch for a stacked PR — resolving any conflicts and force-pushing with lease when done. Use whenever the user says "rebase from parent", "rebase onto main/master", "update my branch from its parent", "rebase this stacked branch", "pull the latest parent into this branch", or otherwise wants the current branch replayed on top of an updated parent. Reach for it even when they don't name the parent — identifying the right parent (trunk vs. stack parent) is this skill's job.
---

# Rebase From Parent

Replay the current branch on top of an up-to-date copy of its **direct parent**, resolve any conflicts, and publish the result with a safe force-push. The three moving parts are: pick the right parent, rebase cleanly, push without clobbering anyone.

## 1. Identify the parent branch

The parent is the branch this one was cut from. Two cases:

- **Direct branch off the trunk** → the parent is the trunk (`main` or `master`).
- **Stacked PR** → the parent is another non-trunk branch that sits between this branch and the trunk. You want to rebase from the *immediate* parent, not the trunk.

Never assume it's the trunk. Work it out from the commit graph:

1. **Find the current branch and the trunk.**
   ```sh
   git rev-parse --abbrev-ref HEAD                 # current branch
   git symbolic-ref --short refs/remotes/origin/HEAD  # origin's default branch, e.g. origin/main
   ```
   If `origin/HEAD` isn't set, fall back to whichever of `origin/main` / `origin/master` exists (`git rev-parse --verify`), or ask the user which is trunk.

2. **Fetch first**, so parent detection and the rebase both use current refs:
   ```sh
   git fetch --all --prune
   ```

3. **Look for a stack parent.** A stack parent is a branch (other than the current one and the trunk) whose tip is an ancestor of `HEAD` *and* which itself carries commits beyond the trunk. Enumerate candidates and check:
   ```sh
   # branches whose tip is an ancestor of HEAD (HEAD is built on top of them)
   for b in $(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin); do
     git merge-base --is-ancestor "$b" HEAD 2>/dev/null && echo "$b"
   done
   ```
   Among those, the parent is the one whose tip is **closest to HEAD** (the fewest commits between it and HEAD: `git rev-list --count <candidate>..HEAD`). If the closest such branch is the trunk, this is a direct branch. If a non-trunk branch is closer, that's the stack parent.

4. **When it's ambiguous, confirm before touching anything.** Detection can be fooled by merged branches, multiple branches at the same commit, or a rewritten parent. State the parent you identified and the number of commits that will be replayed (`git rev-list --count <parent>..HEAD`), and get a nod before rebasing — a wrong parent plus a force-push is expensive to undo.

Prefer the **remote-tracking** tip of the parent (`origin/<parent>`) as the rebase target when it exists and is ahead of the local ref — that's the "latest parent" the user almost always means.

## 2. Rebase

Rebase the current branch onto the parent's up-to-date tip:

```sh
git rebase <parent>            # e.g. git rebase origin/main
```

**Stacked branches with a rewritten parent:** if the parent was itself rebased/force-updated, a plain `git rebase <parent>` will try to replay the parent's *old* commits and produce duplicates or spurious conflicts. In that case rebase only this branch's own commits with `--onto`:

```sh
git rebase --onto <parent> <old-parent-base> <current-branch>
```

where `<old-parent-base>` is the parent's previous tip (the current branch's fork point). `git merge-base --fork-point <parent> HEAD` can often find it; if you just rebased the parent in this same session, use the commit it pointed at beforehand. When unsure which form applies, inspect `git log --oneline <parent>..HEAD` — if it lists commits that don't belong to this branch, switch to `--onto`.

## 3. Resolve conflicts

If the rebase stops on a conflict, **use the `resolving-merge-conflicts` skill** to work through it — that skill owns the conflict-resolution methodology (understanding both sides, resolving correctly, continuing the rebase). Don't hand-wave conflict resolution here; hand off to it, then return to step 4 once the rebase completes (`git rebase --continue` through to a clean tree, or `git rebase --abort` if the user decides to back out).

## 4. Force-push with lease

Once the rebase is complete and the working tree is clean, verify before publishing:

- The branch is where you expect: `git log --oneline --graph -n 20`.
- Nothing is mid-rebase: `git status` shows no rebase in progress.
- The tests/build still pass if that's cheap and relevant — a rebase can silently break things even with no textual conflict.

Then publish with a lease so you can't clobber commits someone else pushed while you were rebasing:

```sh
git push --force-with-lease --force-if-includes
```

`--force-with-lease` refuses the push if the remote moved past what you last fetched; `--force-if-includes` additionally guards against races between your fetch and push. **If the push is rejected**, do NOT reach for `--force`. Re-fetch, understand what changed on the remote (someone else pushed, or the parent moved again), and re-evaluate — possibly re-running this skill from step 1.

## Guardrails

- This skill rewrites history and force-pushes. Both are recoverable via `git reflog`, but only if you notice — so confirm the parent when detection is uncertain, and never escalate a rejected lease push to a plain `--force`.
- Stay on the current branch throughout; this skill rebases the branch you're on, not the parent. Do not modify or push the parent branch.
