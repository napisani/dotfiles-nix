# fff Layout Structure Adjustment Design

**Date:** 2026-04-16

## Goal

Make `fff.nvim` feel less visually distinct from the existing Snacks picker by matching the overall window structure more closely.

## Scope

- Adjust `fff.nvim` layout configuration only.
- Match the broad structure of the Snacks picker:
  - large centered floating window
  - rounded border
  - vertical composition
  - preview above input/results rather than side-by-side
- Do not change picker behavior, keymaps, search semantics, or highlight groups.

## Constraints

- Keep the change isolated to `fff` configuration.
- Preserve the existing root/project file-search spike behavior.
- Accept approximation where `fff` does not expose the same layout primitives as Snacks.

## Success Criteria

- `fff` opens in a large centered floating layout with dimensions close to Snacks.
- The preview is stacked vertically instead of living on the right.
- The change is configuration-only and easy to revert.
