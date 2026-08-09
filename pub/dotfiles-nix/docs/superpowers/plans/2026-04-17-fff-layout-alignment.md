# fff Layout Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `fff.nvim` default to a vertically stacked layout with preview above the search bar and results list, so every `fff` picker feels structurally consistent with Snacks.

**Architecture:** Move `fff` plugin options out of the inline `lazy.lua` spec and into a dedicated `lua/user/fff/init.lua` module so layout policy is centralized. Keep picker call sites unchanged; they should inherit the new global `fff` defaults automatically.

**Tech Stack:** Lua, Neovim 0.12, lazy.nvim, fff.nvim

---

### Task 1: Centralize `fff` setup in a dedicated module

**Files:**
- Create: `mods/dotfiles/nvim/lua/user/fff/init.lua`
- Modify: `mods/dotfiles/nvim/lua/user/lazy.lua`
- Review: `mods/dotfiles/nvim/lua/user/fff/find_files.lua`

- [ ] **Step 1: Write the failing module-load check**

Create `mods/dotfiles/nvim/lua/user/fff/init.lua` with this placeholder content so the require path exists but does not yet expose `opts`:

```lua
local M = {}

return M
```

- [ ] **Step 2: Run the module-load check to verify it fails for the expected reason**

Run: `nvim --headless -c "lua local f = require('user.fff'); assert(type(f.opts) == 'table', 'opts missing')" -c "qa"`
Expected: Neovim exits with an assertion failure containing `opts missing`

- [ ] **Step 3: Write the minimal `fff` setup module**

Replace `mods/dotfiles/nvim/lua/user/fff/init.lua` with:

```lua
local M = {}

M.opts = {
	layout = {
		width = 0.90,
		height = 0.90,
		prompt_position = "bottom",
		preview_position = "top",
		preview_size = 0.45,
		flex = false,
	},
}

return M
```

- [ ] **Step 4: Run the module-load check to verify it passes**

Run: `nvim --headless -c "lua local f = require('user.fff'); assert(type(f.opts) == 'table', 'opts missing')" -c "qa"`
Expected: command exits cleanly with no Lua error

- [ ] **Step 5: Wire `lazy.lua` to the new module**

Update the `fff.nvim` plugin spec in `mods/dotfiles/nvim/lua/user/lazy.lua` from:

```lua
		{
			"dmtrKovalenko/fff.nvim",
			lazy = false,
			opts = {
				layout = {
					width = 0.90,
					height = 0.90,
					prompt_position = "bottom",
					preview_position = "top",
					preview_size = 0.45,
					flex = false,
				},
			},
			build = function()
				require("fff.download").download_or_build_binary()
			end,
		},
```

to:

```lua
		{
			"dmtrKovalenko/fff.nvim",
			lazy = false,
			opts = require("user.fff").opts,
			build = function()
				require("fff.download").download_or_build_binary()
			end,
		},
```

- [ ] **Step 6: Commit the setup extraction**

```bash
git add mods/dotfiles/nvim/lua/user/fff/init.lua mods/dotfiles/nvim/lua/user/lazy.lua
git commit -m "refactor(nvim): centralize fff config"
```

### Task 2: Change the global layout contract to match the approved order

**Files:**
- Modify: `mods/dotfiles/nvim/lua/user/fff/init.lua`
- Review: `docs/superpowers/specs/2026-04-17-fff-layout-design.md`

- [ ] **Step 1: Write the failing layout assertion**

Update `mods/dotfiles/nvim/lua/user/fff/init.lua` temporarily so one assertion will fail by keeping the old prompt position while the rest of the table remains intact:

```lua
local M = {}

M.opts = {
	layout = {
		width = 0.90,
		height = 0.90,
		prompt_position = "bottom",
		preview_position = "top",
		preview_size = 0.45,
		flex = false,
	},
}

return M
```

- [ ] **Step 2: Run the layout assertion to verify it fails**

Run: `nvim --headless -c "lua local layout = require('user.fff').opts.layout; assert(layout.preview_position == 'top', 'preview must be top'); assert(layout.prompt_position == 'top', 'prompt must be top'); assert(layout.flex == false, 'layout must stay vertical')" -c "qa"`
Expected: Neovim exits with an assertion failure containing `prompt must be top`

- [ ] **Step 3: Write the minimal layout change**

Update `mods/dotfiles/nvim/lua/user/fff/init.lua` to:

```lua
local M = {}

M.opts = {
	layout = {
		width = 0.90,
		height = 0.90,
		prompt_position = "top",
		preview_position = "top",
		preview_size = 0.45,
		flex = false,
	},
}

return M
```

- [ ] **Step 4: Run the layout assertion to verify it passes**

Run: `nvim --headless -c "lua local layout = require('user.fff').opts.layout; assert(layout.preview_position == 'top', 'preview must be top'); assert(layout.prompt_position == 'top', 'prompt must be top'); assert(layout.flex == false, 'layout must stay vertical')" -c "qa"`
Expected: command exits cleanly with no Lua error

- [ ] **Step 5: Commit the global layout change**

```bash
git add mods/dotfiles/nvim/lua/user/fff/init.lua
git commit -m "feat(nvim): align fff layout ordering"
```

### Task 3: Verify existing `fff` callers inherit the new defaults unchanged

**Files:**
- Review: `mods/dotfiles/nvim/lua/user/fff/find_files.lua`
- Review: `mods/dotfiles/nvim/lua/user/snacks/find_files.lua`

- [ ] **Step 1: Write the failing integration assertion**

Temporarily change `mods/dotfiles/nvim/lua/user/lazy.lua` so the `fff.nvim` spec points back to an inline empty table:

```lua
		{
			"dmtrKovalenko/fff.nvim",
			lazy = false,
			opts = {},
			build = function()
				require("fff.download").download_or_build_binary()
			end,
		},
```

- [ ] **Step 2: Run the integration check to verify it fails**

Run: `nvim --headless -c "lua local lines = vim.fn.readfile('mods/dotfiles/nvim/lua/user/lazy.lua'); local joined = table.concat(lines, '\n'); assert(joined:match('opts = require%(\"user%.fff\"%)%.opts'), 'lazy spec not wired to user.fff opts'); require('user.fff.find_files'); require('user.snacks.find_files')" -c "qa"`
Expected: Neovim exits with an assertion failure containing `lazy spec not wired to user.fff opts`

- [ ] **Step 3: Restore the minimal correct integration**

Set the `fff.nvim` spec in `mods/dotfiles/nvim/lua/user/lazy.lua` back to:

```lua
		{
			"dmtrKovalenko/fff.nvim",
			lazy = false,
			opts = require("user.fff").opts,
			build = function()
				require("fff.download").download_or_build_binary()
			end,
		},
```

- [ ] **Step 4: Run the integration check to verify it passes**

Run: `nvim --headless -c "lua local lines = vim.fn.readfile('mods/dotfiles/nvim/lua/user/lazy.lua'); local joined = table.concat(lines, '\n'); assert(joined:match('opts = require%(\"user%.fff\"%)%.opts'), 'lazy spec not wired to user.fff opts'); require('user.fff.find_files'); require('user.snacks.find_files')" -c "qa"`
Expected: command exits cleanly with no Lua error

- [ ] **Step 5: Leave the caller modules unchanged**

After the passing check, confirm there is no diff in:

- `mods/dotfiles/nvim/lua/user/fff/find_files.lua`
- `mods/dotfiles/nvim/lua/user/snacks/find_files.lua`

This task is verification-only after `lazy.lua` is restored, so it should not create a separate commit.

### Task 4: Run broad Neovim validation and update docs if needed

**Files:**
- Review: `mods/dotfiles/nvim/lazy-lock.json`
- Review: `docs/superpowers/specs/2026-04-17-fff-layout-design.md`
- Modify: `WORKAROUNDS.md` (only if the final implementation reveals an `fff` layout limitation worth tracking)

- [ ] **Step 1: Run the direct config module check**

Run: `nvim --headless -c "lua require('user.fff')" -c "qa"`
Expected: command exits cleanly with no Lua error

- [ ] **Step 2: Run the existing wrapper module check**

Run: `nvim --headless -c "lua require('user.fff.find_files')" -c "qa"`
Expected: command exits cleanly with no Lua error

- [ ] **Step 3: Run the which-key loader check**

Run: `nvim --headless -c "lua require('user.whichkey.find_snacks')" -c "qa"`
Expected: command exits cleanly with no Lua error

- [ ] **Step 4: Run the broad config health check**

Run: `nvim --headless -c "checkhealth" -c "qa"`
Expected: no new Lua startup errors introduced by the `fff` layout change

- [ ] **Step 5: Record any discovered upstream/layout limitation if needed**

If `fff` cannot truly render `preview -> input -> results` and only approximates it, add a short note to `WORKAROUNDS.md` like:

```md
## fff.nvim layout ordering

`fff.nvim` is configured for the closest available vertical layout to match Snacks, but its layout primitives may not support exact section ordering beyond `preview_position` and `prompt_position`.
```

If no limitation is discovered during implementation, do not change `WORKAROUNDS.md`.

- [ ] **Step 6: Commit the validated final state**

```bash
git add mods/dotfiles/nvim/lua/user/fff/init.lua mods/dotfiles/nvim/lua/user/lazy.lua
if [ -f WORKAROUNDS.md ] && ! git diff --quiet -- WORKAROUNDS.md; then git add WORKAROUNDS.md; fi
git commit -m "chore(nvim): validate fff layout alignment"
```
