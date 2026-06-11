---
name: multi-valued-review
description: Run a multi-lens code review over a diff, whole project, path, or explicit files. Use when the user asks for a multi-valued review, multi-lens review, parallel review across correctness/security/reliability/complexity/evolvability, code quality review, best-practices review, bug/edge-case review, performance/security/maintainability review, framework idiom review, or review with scope=diff, scope=project, scope=path:, or scope=files:.
---

# Multi-Valued Review

Use this skill to run a read-only code review across five value-based lenses:

1. `correctness-invariants`
2. `security-trust-boundaries`
3. `reliability-operability`
4. `complexity-simplification`
5. `evolvability-maintainability`

This skill replaces the older OpenCode-only `/multi-valued-review` command and `review-multi-valued-orchestrator` subagent.

## Core Rules

- Treat the review as read-only. Do not edit files.
- Provide constructive feedback without making direct changes.
- Prefer `rg` and `rg --files` for repository search and file discovery.
- Keep findings evidence-based and tied to concrete files, lines, diffs, commands, or scenarios.
- Do not report speculative issues without a plausible failure mode.
- Do not report pure style preferences or formatting nits.
- Prefer findings about behavior, risk, maintainability, performance, security, framework idioms, and concrete simplification opportunities.
- Critical and High severity findings are Blocking.
- Medium and Low severity findings are Non-Blocking.
- Never abbreviate severity labels. Write `Critical`, `High`, `Medium`, and `Low` in full everywhere, including category totals.
- Deduplicate findings by root cause. Preserve the category from the lens that found the issue first, unless another category better explains the root cause.
- When findings conflict, keep the higher severity only if the evidence supports it; otherwise keep the better-evidenced finding.

## Scope Arguments

Parse the user's request for a `scope=...` argument:

- Default: `scope=diff`
- Full repository: `scope=project`
- Directory or glob: `scope=path:<dir-or-glob>`
- Explicit files: `scope=files:<file1,file2,...>`

If the scope is missing, use `diff` and set `Scope Input` to `N/A`.
If the scope is invalid, fall back to `diff` and set `Scope Fallback` to `invalid-scope->diff`.

Preserve any additional user text, such as `focus=complexity hotspots`, as review focus context without changing the resolved scope.

## Build Review Context

### `scope=diff`

Review current branch and worktree changes. Gather:

```sh
git status --short
git diff --stat
git diff
git diff --cached --stat
git diff --cached
```

When possible, also inspect the branch diff against a merge base:

```sh
git branch --show-current
git merge-base HEAD @{upstream}
git diff "$(git merge-base HEAD @{upstream})"...HEAD --stat
git diff "$(git merge-base HEAD @{upstream})"...HEAD
```

If there is no upstream, try a likely base branch such as `origin/main`, `origin/master`, `main`, or `master`. If no merge base is available, continue with staged and unstaged changes.

### `scope=project`

Build representative whole-repository context. Use `rg --files` and prioritize:

- entrypoints, manifests, and build/runtime configuration
- high-churn files from recent history
- auth, authorization, permissions, secrets, config, database, migration, queue, cache, network, and deployment paths
- test files that describe expected invariants or important workflows

Useful commands:

```sh
rg --files
git log --name-only --pretty=format: --since='90 days'
rg -n "auth|permission|secret|token|password|encrypt|decrypt|migration|queue|retry|timeout|cache|transaction|lock"
```

Avoid trying to read the entire repository when it is large. Sample enough files to support concrete findings.

### `scope=path:<dir-or-glob>`

Resolve matching files under the requested directory or glob. If a directory exists, prefer:

```sh
rg --files <path>
```

If the argument is a glob, resolve the matching tracked or repository files with the shell or `rg --files` plus filtering. Only review files that exist.

### `scope=files:<file1,file2,...>`

Split the comma-separated list, trim whitespace, and review only files that exist. Ignore missing files, but keep the original raw scope in `Scope Input`.

## Review Lenses

Run each lens as an independent pass over the same resolved scope and file set. If the current agent platform supports parallel subagents or tasks, the passes may run in parallel. Otherwise, run them sequentially while keeping notes separate until consolidation.

### `correctness-invariants`

Focus on:

- logical correctness and functional behavior
- domain and business invariants
- contract preservation across APIs, data shapes, and call boundaries
- edge-case handling and error-path behavior
- backward compatibility of behavior and APIs
- invalid state transitions, concurrency issues, off-by-one errors, stale assumptions, and tests that no longer match implementation behavior

Do not report style-only issues. Do not report security, reliability, or performance concerns under this category unless they directly break correctness.

### `security-trust-boundaries`

Focus on:

- authentication and authorization correctness
- input validation, injection, and unsafe deserialization risks
- secrets handling and sensitive data exposure
- trust boundary violations across service, user, network, process, and system boundaries
- overbroad permissions, insecure defaults, and abuse paths where external data is treated as trusted

Do not report style-only issues. Do not report maintainability concerns under this category unless they create a security risk.

### `reliability-operability`

Focus on:

- failure modes, timeout and retry behavior, cancellation, and idempotency
- deployment safety, migrations, and rollback readiness
- logging, metrics, and observability gaps that affect incident response
- config and runtime risks that can cause outage or degraded service
- resource leaks, race-prone startup or shutdown behavior, weak error recovery, and performance implications that create runtime risk

Do not report style-only issues. Do not report pure architecture preferences under this category unless they create production runtime risk.

### `complexity-simplification`

Focus on:

- unnecessary abstraction and accidental complexity
- branching or state explosion and high cognitive load
- API surface sprawl and over-generalized design
- duplicated logic, hard-to-follow control flow, needless indirection, unclear names, and code that can be simplified while preserving behavior
- language or framework idioms where the current approach is materially harder to understand or maintain than the conventional approach

Do not report pure style nits. Do not recommend broad rewrites unless they are necessary for clear risk reduction.

### `evolvability-maintainability`

Focus on:

- modularity, coupling, and boundary clarity
- readability and testability that affect future change speed
- duplication patterns and ownership confusion
- long-term maintainability risks and technical debt growth
- brittle APIs, missing tests around extension points, undocumented conventions, hard-to-change data shapes, and implementation choices that make likely future changes expensive
- language and framework conventions where non-idiomatic code will make future work slower or riskier

Do not report style-only preferences. Do not duplicate findings already captured as correctness, security, or reliability unless this lens adds distinct long-term impact.

## Consolidation

After all five passes:

1. Merge findings into one list.
2. Remove duplicates that share a root cause.
3. Assign stable IDs in report order: `F-001`, `F-002`, and so on.
4. Sort Blocking Issues before Non-Blocking Issues.
5. Within each section, sort by severity, then confidence, then source order.
6. Compute category totals by severity.

Use these severity labels only:

- `Critical`
- `High`
- `Medium`
- `Low`

Use these confidence labels only:

- `High`
- `Medium`
- `Low`

## Output Format

Return markdown only, using this schema. Always include every required heading, even when there are no findings. Use `N/A` when a field does not apply.

```markdown
## Review Summary
- **Resolved Scope:** diff|project|path|files
- **Scope Input:** <raw scope argument or N/A>
- **Scope Fallback:** none|invalid-scope->diff
- **Files Considered:** <count>
- **Overall Risk:** Low|Medium|High
- **Blocking Issues:** <count>
- **Non-Blocking Issues:** <count>

## Blocking Issues
If none, write: `No blocking issues found.`

### [F-001] <short title>
- **Blocking:** Yes
- **Severity:** Critical|High
- **Category:** correctness-invariants|security-trust-boundaries|reliability-operability|complexity-simplification|evolvability-maintainability
- **Location:** path/to/file.ext:line or N/A
- **Comment:** <code-linked finding>
- **Why It Matters:** <impact>
- **Suggested Fix:** <concrete fix or N/A>
- **Confidence:** High|Medium|Low
- **Evidence:** <snippet/scenario or N/A>

## Non-Blocking Issues
If none, write: `No non-blocking issues found.`

### [F-00X] <short title>
- **Blocking:** No
- **Severity:** Medium|Low
- **Category:** correctness-invariants|security-trust-boundaries|reliability-operability|complexity-simplification|evolvability-maintainability
- **Location:** path/to/file.ext:line or N/A
- **Comment:** <code-linked finding>
- **Why It Matters:** <impact>
- **Suggested Fix:** <concrete fix or N/A>
- **Confidence:** High|Medium|Low
- **Evidence:** <snippet/scenario or N/A>

## Category Totals
- **correctness-invariants:** Critical:<n> High:<n> Medium:<n> Low:<n>
- **security-trust-boundaries:** Critical:<n> High:<n> Medium:<n> Low:<n>
- **reliability-operability:** Critical:<n> High:<n> Medium:<n> Low:<n>
- **complexity-simplification:** Critical:<n> High:<n> Medium:<n> Low:<n>
- **evolvability-maintainability:** Critical:<n> High:<n> Medium:<n> Low:<n>
```
