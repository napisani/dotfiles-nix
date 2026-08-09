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

