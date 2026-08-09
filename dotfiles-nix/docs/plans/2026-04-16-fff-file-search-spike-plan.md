# fff File Search Spike Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `fff.nvim` as a narrow spike for root/project file search only, routing `<leader>fr` through `fff` while leaving all other Snacks picker behavior unchanged.

**Architecture:** Keep Snacks as the primary picker framework. Add a thin `fff` wrapper module and swap only the `find_files_from_root()` code path to call that wrapper. Preserve the existing keymaps and minimize the diff so rollback is one small revert.

**Tech Stack:** Lua, lazy.nvim, Snacks.nvim, fff.nvim, Neovim 0.12

---

### Task 1: Add the plugin and wrapper entrypoint

**Files:**
- Modify: `mods/dotfiles/nvim/lua/user/lazy.lua`
- Create: `mods/dotfiles/nvim/lua/user/fff/find_files.lua`

**Step 1: Write the minimal plugin declaration**

Add `dmtrKovalenko/fff.nvim` to the `lazy.nvim` spec with no extra behavior changes.

**Step 2: Write the wrapper module**

Create one function that:
- safely requires `fff`
- computes the project root
- opens `fff` for project-root file search
- applies an initial query when the plugin API supports it
- falls back cleanly with `vim.notify` if `fff` is unavailable

**Step 3: Verify the module loads**

Run: `nvim --headless -c "lua require('user.fff.find_files')" -c "qa"`
Expected: exits cleanly with no Lua error

### Task 2: Reroute only the root/project file-search helper

**Files:**
- Modify: `mods/dotfiles/nvim/lua/user/snacks/find_files.lua`
- Review: `mods/dotfiles/nvim/lua/user/whichkey/find_snacks.lua`

**Step 1: Update the helper**

Change `find_files_from_root()` to delegate to the new `fff` wrapper.

**Step 2: Keep all other helpers unchanged**

Do not modify:
- `find_path_files()`
- `toggle_explorer_tree()`
- git file helpers
- grep helpers

**Step 3: Verify keymap wiring still resolves**

Run: `nvim --headless -c "lua require('user.whichkey.find_snacks')" -c "qa"`
Expected: exits cleanly with no Lua error

### Task 3: Validate no grep regressions in configuration load

**Files:**
- Review: `mods/dotfiles/nvim/lua/user/snacks/search_files.lua`
- Review: `mods/dotfiles/nvim/lua/user/whichkey/search_snacks.lua`

**Step 1: Confirm grep modules remain unchanged**

Ensure the diff does not touch the Snacks grep path.

**Step 2: Run config-level checks**

Run: `nvim --headless -c "lua require('user.whichkey.plugins'); print(vim.inspect(require('user.whichkey.plugins').get_all_plugin_keymaps()))" -c "qa"`
Expected: exits cleanly and prints keymap data

### Task 4: Sanity-check the full startup path

**Files:**
- Review final diff only

**Step 1: Run a broad health load**

Run: `nvim --headless -c "checkhealth" -c "qa"`
Expected: no new Lua errors introduced by the spike

**Step 2: Commit**

```bash
git add mods/dotfiles/nvim/lua/user/lazy.lua \
  mods/dotfiles/nvim/lua/user/fff/find_files.lua \
  mods/dotfiles/nvim/lua/user/snacks/find_files.lua \
  docs/plans/2026-04-16-fff-file-search-spike-design.md \
  docs/plans/2026-04-16-fff-file-search-spike-plan.md
git commit -m "feat(nvim): spike fff for root file search"
```
