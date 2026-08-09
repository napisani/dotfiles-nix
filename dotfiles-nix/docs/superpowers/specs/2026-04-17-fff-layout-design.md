# fff Global Layout Alignment Design

**Date:** 2026-04-17

## Goal

Make every `fff` picker use a layout structure that feels consistent with the existing Snacks picker experience, with this vertical order:

1. preview at the top
2. search/input bar
3. result list

## Scope

- Apply one default layout contract to all `fff` pickers.
- Keep the change in the `fff` integration/config layer.
- Preserve existing Snacks picker behavior.
- Preserve existing `fff` caller behavior, including the current root file-search wrapper.

## Non-Goals

- Do not migrate more picker flows from Snacks to `fff`.
- Do not change keymaps.
- Do not change search semantics, matching behavior, or root detection.
- Do not introduce a shared cross-framework abstraction for Snacks and `fff`.

## Current Context

- `fff` is currently used through `lua/user/fff/find_files.lua` as a narrow wrapper for root/project file search.
- A prior design note already established the desired structural direction: stack preview above the rest of the picker instead of using a side-by-side layout.
- The broader user goal is consistency across picker frameworks, so the layout policy should live at `fff` setup time rather than at individual picker call sites.

## Recommended Approach

Configure `fff` once through a dedicated setup/config module and declare the layout order there as the global default.

This keeps layout policy centralized and makes future `fff` pickers inherit the same structure automatically. Individual picker entrypoints remain responsible only for picker-specific behavior such as cwd, initial query, or fallback behavior.

## Design

### Configuration Boundary

- Add or update a dedicated `fff` setup/config module.
- Ensure `fff.setup()` is called from the existing Neovim config initialization path.
- Keep layout defaults in that setup module, not inside `find_files_from_root()` or future picker wrappers.

### Layout Contract

- `fff` should default to a vertical stacked layout.
- The visual order should be:
  1. preview
  2. input/search
  3. results
- If `fff` exposes exact section ordering controls, use them directly.
- If `fff` only exposes higher-level layout presets, choose the closest supported preset that still produces the same effective visual hierarchy.

### Caller Responsibilities

- Existing wrapper modules may continue to choose root/cwd and pass initial query text.
- Caller modules should not define layout unless a future picker has a concrete need to opt out.
- Any future override should be explicit and local so the global default remains the norm.

## Validation

- Load the `fff` config/setup module directly in headless Neovim to verify it has no Lua errors.
- Load the existing `lua/user/fff/find_files.lua` wrapper after the setup change to ensure the wrapper still resolves cleanly.
- Run a broader Neovim config check if needed to confirm the updated setup path does not introduce startup errors.

## Risks

- `fff` may not expose a primitive that exactly matches the desired ordering. In that case, use the closest available vertical structure and keep the compromise isolated to the setup module.
- `fff` initialization may currently be implicit or incomplete. A small `lazy.lua` adjustment may be required so setup runs reliably before pickers are opened.

## Success Criteria

- Every `fff` picker inherits the same default vertical layout.
- The effective visual order is preview first, then input, then results.
- Existing Snacks pickers remain unchanged.
- The change stays small, centralized, and easy to revert.
