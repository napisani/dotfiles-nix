---
description: Run a multi-valued parallel review (correctness, security, reliability, complexity, evolvability)
agent: review-multi-valued-orchestrator
subtask: true
---

Run a multi-valued code review with configurable review scope.

Arguments: $ARGUMENTS

Scope selection:
- Default: `scope=diff` (current branch/worktree changes)
- Full repository: `scope=project`
- Directory or glob: `scope=path:<dir-or-glob>`
- Explicit files: `scope=files:<file1,file2,...>`

Examples:
- `/multi-valued-review`
- `/multi-valued-review scope=project`
- `/multi-valued-review scope=path:mods/dotfiles/nvim`
- `/multi-valued-review scope=files:mods/dotfiles/opencode/commands/multi-valued-review.md,mods/dotfiles/opencode/agents/review-multi-valued-orchestrator.md`
- `/multi-valued-review scope=project focus=complexity hotspots`

Requirements:
1. Parse `$ARGUMENTS` to resolve scope:
   - `diff`, `project`, `path`, or `files`
   - if scope is invalid, fall back to `diff` and note that fallback in output
2. Build review context from resolved scope:
   - `diff`: git status, changed files, staged/unstaged diffs, and branch diff vs merge base when available
   - `project`: representative whole-repo review context with priority on entrypoints, high-churn files, and critical runtime/security files
   - `path`: files matching provided directory or glob
   - `files`: only explicitly listed files that exist
3. Pass resolved scope and selected file set to all review subagents.
4. Invoke these value-lens subagents in parallel:
   - review-correctness-invariants
   - review-security-trust-boundaries
   - review-reliability-operability
   - review-complexity-simplification
   - review-evolvability-maintainability
5. Consolidate and deduplicate findings while preserving category ownership.
6. Output markdown with consistent finding fields and `N/A` for non-applicable attributes.
