# Stackman PR Discovery Design

## Goal

Add `stackman discover` to import existing stacked PR branches into Stackman's local tracking database when GitHub PR metadata already describes the stack.

## CLI

```bash
stackman discover PR_NUMBER
stackman discover PR_NUMBER --apply
```

- `PR_NUMBER` is required.
- The PR number is the starting node for discovery.
- Without `--apply`, the command is read-only and prints the discovered stack/tree plus the equivalent tracking plan.
- With `--apply`, the command writes Stackman tracking metadata for discovered branches that exist locally.

## GitHub boundary

`discover` is the only Stackman command allowed to invoke the GitHub CLI. The rest of Stackman remains Git-provider agnostic and continues to depend only on Git plus SQLite.

The command shells out to:

```bash
gh pr view PR_NUMBER --json headRefName,baseRefName,number,title,url,state
gh pr list --state open --limit 1000 --json headRefName,baseRefName,number,title,url,state
```

If `gh` is missing, unauthenticated, or fails, `discover` exits with a clear error. No other command imports or calls GitHub-specific code.

## Discovery model

Each open PR contributes one edge:

```text
baseRefName -> headRefName
```

Given `PR_NUMBER`:

1. Fetch that PR and treat its `headRefName` as the starting node.
2. Walk upward through PR base branches until reaching a base that is not itself an open PR head. That base is the stack anchor.
3. Use the topmost PR branch on that path as the root of the selected stack subtree.
4. Traverse descendants from that root through PR edges.
5. Print the anchor, discovered PR tree, and a topological tracking plan.

This intentionally does **not** traverse every open PR based on the anchor branch. For example, if the anchor is `main`, discovery imports the selected PR's stack subtree rather than every open PR targeting `main`.

The command supports fan-out trees, not only linear chains.

## Apply behavior

`--apply` reuses Stackman's existing branch-first tracking behavior:

- import branches in parent-before-child order
- for each import, call the same tracking path as `stackman track BRANCH --parent PARENT`
- only apply branches whose head and parent branches exist locally
- skip descendants whose parent was skipped
- report missing local branches/parents as skipped
- never fetch, checkout, delete branches, or call GitHub outside discovery

## Testing

Tests use real Git repositories and a fake `gh` executable placed on `PATH`, so discovery still exercises subprocess execution without requiring GitHub network access.

Coverage:

- CLI help exposes `discover` and requires `PR_NUMBER`
- read-only discovery renders a tree and plan without changing the DB
- `--apply` records discovered parent/child lineage
- missing local PR branches are marked/skipped
- unrelated open PRs sharing the same anchor are not imported
