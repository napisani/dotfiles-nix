---
name: address-pr-feedback
description: Use when the user wants to handle GitHub pull request feedback, review comments, reviewer suggestions, pasted PR comments, or a PR URL with comments that need triage, code changes, or drafted reviewer replies.
---

# Address PR Feedback

Use this skill to triage pull request feedback, decide which reviewer comments deserve code changes, implement only the approved fixes, and draft responses for the user to post manually.

The core distinction is important: comments that the user has already answered with an intended fix are already decided; unanswered comments are not decided until the user confirms what to change.

## Inputs

The user may provide either:

- A GitHub pull request URL with review comments.
- Pasted PR comments plus the relevant file paths, code snippets, or diff hunks.

If a PR URL is provided, use `gh` to gather review context. Prefer JSON commands and keep the raw comment metadata available while analyzing.

Useful commands:

```sh
gh pr view "<PR_URL>" --json number,url,title,author,headRefName,baseRefName,files,reviews,comments
gh api user --jq .login
gh api "repos/OWNER/REPO/pulls/NUMBER/comments" --paginate
gh api "repos/OWNER/REPO/issues/NUMBER/comments" --paginate
gh api "repos/OWNER/REPO/pulls/NUMBER/reviews" --paginate
```

Use the URL to identify `OWNER`, `REPO`, and `NUMBER`. If the PR branch is not available locally, inspect the existing worktree first, then fetch or check out the PR branch only when needed and safe for the current repository state.

## Classify Feedback

Build a feedback inventory before editing code.

For each distinct feedback item, record:

- Stable ID, such as `PF-001`.
- Reviewer name.
- File path and line if available.
- Relevant code line or snippet.
- Original reviewer comment.
- Any replies in the same review thread.
- Whether the user has already promised a fix.
- Whether the comment asks for a potential code change, a clarification only, or no action.

Treat a comment as an already-promised fix only when the user's reply clearly commits to a specific change, such as "I'll rename this", "will update this to use X", "done in next push", or "I'll add the missing test". If the reply is ambiguous, classify it as undecided.

When the user has already promised a fix, assume that fix should be made. Do not re-litigate it unless implementation reveals a serious technical problem.

When a comment has no user reply committing to a fix, do not change code for it yet. Analyze it and ask the user to confirm whether to fix it or only respond.

## Analysis Report

Before making code changes, present a report for every feedback item that could plausibly lead to a code change. Include already-promised fixes and undecided items, but clearly separate them.

Use this dense decision-sheet format. Keep the index tables short, then expand only the items that need a user decision.

````markdown
## PR Feedback Decision Sheet

### Already Promised

| ID | File | Reviewer | Promised fix | Status |
|---|---|---|---|---|
| PF-001 | path/to/file.ts | <name> | <specific user-promised fix> | Will implement |

### Needs Decision

| ID | Rec | R/I/W | File / section | Reviewer ask |
|---|---|---|---|---|
| PF-002 | Fix / Respond only / Skip | L/M/H | path/to/file.ts · <function/component/block> | <short reviewer ask> |

R/I/W = Risk / Importance / Rework

#### PF-002: <short title>
file: `path/to/file.ts`
section: `<line number or nearest function/component/block>`
original comment: "<reviewer's exact comment text>"

```ts
<the relevant code excerpt, usually 3-8 lines>
```

recommendation: <Fix|Respond only|Skip> - <one or two sentence rationale, including whether you agree and whether a code change is recommended>
next step: <concrete next action, including what to change or what to say if not changing code>

## Decision Needed
Please confirm which `Needs Decision` IDs should be fixed. You can overrule any recommendation.
````

Use the rating meanings exactly:

- `Risk level introduced`: `High`, `Medium`, or `Low`.
- `Importance`: `High`, `Medium`, or `Low`.
- `Rework level`: `High`, `Medium`, or `Low`.

Risk means the risk introduced by implementing the suggested change, not the risk of ignoring it. Importance means how critical the suggestion is to the original PR initiative. Rework means how much code needs to change.

In the table, compress the ratings as `R/I/W` using `L`, `M`, or `H`. In the expanded cards, use plain labels `recommendation` and `next step` instead of repeating every rating line.

For every item under `Needs Decision`, preserve the original reviewer comment exactly when available. Include enough surrounding code for the user to understand the request without opening the PR. If the exact line is not available, name the nearest function, component, test, class, or diff hunk and include the smallest useful code excerpt.

## Wait For Confirmation

After presenting the triage report:

- Implement all `Already Promised Fixes` unless the user tells you not to.
- For `Needs Decision` items, wait for the user to say which IDs to fix.
- The user may overrule recommendations.
- Do not implement undecided feedback just because it seems obvious.

If all actionable comments were already promised fixes, say that and proceed with those fixes.

## Implement Fixes

Once the decided set is known:

1. Inspect the affected code and nearby tests before editing.
2. Make the promised or approved code changes.
3. Keep edits limited to the feedback being addressed.
4. Add or update tests when the feedback changes behavior, contracts, or important edge cases.
5. Run the smallest meaningful verification command first, then broader checks when risk or blast radius justifies it.
6. Do not commit changes.
7. Do not post comments to GitHub.

If a promised fix turns out to be technically wrong or unsafe, stop and explain the blocker before substituting a different fix.

## Draft Responses

After implementing approved fixes and running verification, provide response drafts for every feedback item, including items that were not changed.

Do not make comments directly on GitHub. Keep every response in chat for the user to copy or revise.

Use this format for each item:

```text
file: file/name.ts
line of code: const x = () => {}
reviewer 1: this function should be named y and it should use the function keyword
recommended response: I have updated this to use the function keyword and renamed it to y.
```

For no-change decisions, recommend a concise response that explains why no code change was made:

```text
recommended response: I looked into this and kept the current implementation because <reason>. The existing behavior is covered by <test/context>.
```

## Final Response

Finish with:

- A short summary of code changes made.
- Verification commands run and their results.
- A clear note that no commit was made.
- The response drafts for every feedback item.

Avoid saying that comments were resolved unless you actually posted to GitHub, which this skill does not do.
