# Shared Agent Instructions

This file is the single editable source for global coding-agent instructions.
Home Manager copies it into each agent's preferred global context path after
RTK hook initialization.

## Shell Commands

Always prefix shell commands with `rtk`.

Examples:

```bash
rtk git status
rtk cargo test
rtk npm run build
rtk pytest -q
```

## RTK Meta Commands

```bash
rtk gain
rtk gain --history
rtk proxy <cmd>
```

## Verification

```bash
rtk --version
rtk gain
which rtk
```

## Coding Preferences

- Prefer existing project patterns over new abstractions.
- Do not revert user changes unless explicitly asked.
- Keep edits scoped to the requested behavior.
- Run the smallest useful verification before calling work complete.

## Workspace Task Snapshot

If `.vantage/` exists in the current workspace, maintain `.vantage/agent-context.md` as a compact snapshot of the active task.

Create `.vantage/agent-context.md` if it is missing. Rewrite the file when task state materially changes; do not append a running log or transcript.

Keep the snapshot concise, current, and under 12 KB when practical. Do not include secrets, credentials, raw conversation, or unrelated project documentation.

Use this structure:

# Agent Task Context

## Goal

## Current Focus

## Relevant Files

## Decisions

## Constraints

## Open Questions

## Recent Progress

Update it after meaningful changes: plan changes, important files or constraints are discovered, decisions are made, tests pass/fail in a relevant way, or before handing control back to the user.

Do not update it after every command, file read, or tool call.
