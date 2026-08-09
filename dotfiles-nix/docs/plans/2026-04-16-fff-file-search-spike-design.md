# fff File Search Spike Design

**Date:** 2026-04-16

## Goal

Spike `dmtrKovalenko/fff.nvim` into the Neovim config as a narrow replacement for the root/project file search flow, without changing the broader Snacks-based picker workflow.

## Scope

- Add `fff.nvim` to the Neovim plugin set.
- Route only the root/project file-search helper used by `<leader>fr` through `fff`.
- Leave all grep flows under `<leader>h*` on Snacks.
- Leave all other file-pickers (`<leader>ft`, `<leader>fp`, git-changed pickers, buffers, help, man, etc.) on Snacks.

## Constraints

- Preserve the documented picker contract: file-finding remains fuzzy and filter-as-you-type.
- Preserve the current keymap surface area.
- Preserve visual-mode prefill behavior for `<leader>fr` if `fff` supports an initial query cleanly.
- Do not broaden this spike into a full picker migration.

## Approach

1. Add `fff.nvim` to `lazy.nvim`.
2. Introduce a small wrapper module in `lua/user/fff/` that encapsulates `fff` setup details and exposes one function for root/project file search.
3. Update the existing root file-search helper in `lua/user/snacks/find_files.lua` to delegate to the new wrapper for `<leader>fr` callers.
4. Keep the rest of the Snacks wrappers unchanged so rollback is trivial.

## Risks

- `fff.nvim` may not support the same initial query/pattern semantics as Snacks. If that happens, the wrapper should degrade explicitly and keep the change isolated to `<leader>fr`.
- `fff.nvim` may assume a different root/cwd model than Snacks. The wrapper should force project-root behavior to match the existing contract for `<leader>fr`.

## Success Criteria

- `<leader>fr` opens `fff` instead of Snacks.
- The picker still behaves as fuzzy file search rooted at the project/repository root.
- No `<leader>h*` behavior changes.
- No other picker bindings change behavior.
