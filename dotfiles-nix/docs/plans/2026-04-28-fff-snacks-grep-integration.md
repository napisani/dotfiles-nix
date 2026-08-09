# fff.nvim + Snacks Picker Grep Integration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Use fff.nvim's in-process Rust grep engine as the data source for snacks.nvim's live-grep picker, replacing the rg subprocess with fff's Lua API while keeping the snacks picker UI exclusively.

**Architecture:** fff.nvim is installed and initialized (it self-initializes lazily when the Neovim process starts). A custom snacks finder function calls `require('fff.grep').search(query)` synchronously on each keystroke and converts the result items into snacks item format, then streams them via `ctx.add_item()`. The existing `<leader>hr` and related grep bindings are rewired to use this new finder. The git-scoped grep pickers (`<leader>hd`, `<leader>hD`, `<leader>hq`) continue using rg via snacks' built-in grep because fff doesn't support pre-filtering to an explicit file list in its current API.

**Tech Stack:** Lua, lazy.nvim, fff.nvim (Rust-backed Neovim plugin), snacks.nvim custom finder API

---

## Background: How Snacks Picker Finders Work

A snacks finder is a function `(opts, ctx) -> fn`. The returned function is called by snacks on each search change. You populate items by calling the `ctx` object — specifically by returning items directly or adding them via an async mechanism.

The simplest pattern for a synchronous Lua-based finder:

```lua
---@type snacks.picker.finder
local function my_finder(opts, ctx)
  -- Called once per search; return nothing (snacks handles debounce)
  -- Use ctx:filter() to get the current query
  local query = ctx.filter.search
  local results = some_search(query)

  -- snacks expects the finder to return a generator function that yields items
  -- For synchronous data: return a function that iterates items once
  local i = 0
  return function()
    i = i + 1
    return results[i]  -- snacks calls this until nil
  end
end
```

Items must have at minimum: `{ file = "path/to/file.lua", pos = { line, col }, text = "display", line = "matched line content" }`

## Background: fff Grep API

```lua
-- Initialize fff (done once automatically on first use)
require('fff.core').ensure_initialized()

-- Search (synchronous, returns a SearchResult table)
local result = require('fff.grep').search(
  query,        -- string, may contain fff constraint syntax like "*.rs !test/"
  file_offset,  -- number, pagination (0 = start)
  page_size,    -- number, max results (use large number like 500 for snacks)
  config,       -- table, optional: { max_file_size, max_matches_per_file, smart_case, time_budget_ms }
  grep_mode     -- string: "plain" | "regex" | "fuzzy"
)

-- result.items is a list of match objects
-- Each item has:
--   item.relative_path   -- string: file path relative to cwd
--   item.line_number     -- number: 1-indexed line
--   item.column_number   -- number: 1-indexed column
--   item.line_content    -- string: the matched line text
--   item.match_start     -- number: byte offset of match start in line_content
--   item.match_end       -- number: byte offset of match end in line_content
```

---

## Task 1: Install fff.nvim via lazy.nvim

**Files:**
- Modify: `mods/dotfiles/nvim/lua/user/lazy.lua` (around line 291, before the closing `}` of the spec)

**Step 1: Add the fff.nvim spec to lazy.lua**

Add this block near the bottom of the `spec = { ... }` table in `lazy.lua`, before the closing `},` of the spec:

```lua
{
    "dmtrKovalenko/fff.nvim",
    lazy = false, -- fff self-initializes lazily internally, but we want it loaded at startup
    build = function()
        require("fff.download").download_or_build_binary()
    end,
},
```

**Step 2: Verify lazy.lua is valid Lua**

```bash
nvim --headless -c "lua require('user.lazy')" -c "qa" 2>&1
```

Expected: No output (silent success). Any Lua parse error will be printed.

**Step 3: Install the plugin**

Open Neovim and run `:Lazy sync`. fff.nvim should appear in the install list. Watch for the build step downloading the binary.

Alternatively, from the shell:
```bash
nvim --headless -c "Lazy! sync" -c "qa" 2>&1
```

**Step 4: Verify fff installed and binary works**

```bash
nvim --headless -c ":FFFHealth" -c "qa" 2>&1
```

Expected: Health check output with no errors about missing binary.

---

## Task 2: Create the fff plugin setup module

**Files:**
- Create: `mods/dotfiles/nvim/lua/user/plugins/util/fff.lua`
- Modify: `mods/dotfiles/nvim/lua/user/plugin_registry.lua`

**Step 1: Create the module**

```lua
-- lua/user/plugins/util/fff.lua
local M = {}

function M.setup()
	local ok, fff = pcall(require, "fff")
	if not ok then
		vim.notify("fff.nvim not found", vim.log.levels.WARN)
		return
	end

	fff.setup({
		lazy_sync = true, -- don't block startup on scanning

		grep = {
			smart_case = true,
			max_matches_per_file = 200,
			time_budget_ms = 150,
			modes = { "plain", "regex", "fuzzy" },
		},

		frecency = {
			enabled = true,
		},

		-- Disable fff's own picker UI (we use snacks for that)
		-- fff.nvim doesn't have a "disable picker" flag, but setting lazy = false
		-- in lazy.lua means fff initializes and indexes in the background.
		-- We simply never call fff.find_files() or fff.live_grep() directly.
	})
end

return M
```

**Step 2: Register in plugin_registry.lua**

Add `"util.fff"` to the end of `M.modules` in `plugin_registry.lua`:

```lua
-- Util plugins
"util.fff",
```

**Step 3: Test module loads**

```bash
nvim --headless -c "lua require('user.plugins.util.fff').setup()" -c "qa" 2>&1
```

Expected: Silent (no errors). If fff binary isn't installed yet, you'll get a warning — that's OK, run `:Lazy sync` first.

---

## Task 3: Write the custom snacks finder backed by fff grep

**Files:**
- Create: `mods/dotfiles/nvim/lua/user/snacks/fff_grep.lua`

This is the core of the integration. Snacks's `picker.grep` under the hood calls a finder function. We bypass it and call `Snacks.picker()` directly with our own finder.

**Step 1: Understand the snacks finder contract**

A finder is `function(opts, ctx) -> iterator`. The iterator is called by snacks repeatedly until it returns `nil`. Items need these fields:

```lua
{
  file = "relative/path/to/file.lua",  -- used by snacks to open the file
  pos  = { line_number, col_number - 1 }, -- 0-indexed column for cursor position
  text = "file.lua:10:5:matched line", -- full display text (shown in list)
  line = "matched line content",       -- the matched line (used for highlights)
}
```

**Step 2: Create fff_grep.lua**

```lua
-- lua/user/snacks/fff_grep.lua
--
-- Custom snacks picker using fff.nvim's Rust grep engine as the backend.
-- fff keeps an in-process warm index, making repeated greps much faster than
-- spawning rg subprocesses.

local Snacks = require("snacks")
local utils = require("user.utils")

local M = {}

-- Maximum matches to request from fff per query.
-- fff paginates; we ask for a large page to get all results in one call.
-- Increase if you work on very large repos.
local MAX_RESULTS = 500

--- Convert a fff grep result item into a snacks picker item.
--- fff item fields:
---   relative_path  (string)
---   line_number    (number, 1-indexed)
---   column_number  (number, 1-indexed)
---   line_content   (string)
---@param fff_item table
---@param cwd string  absolute cwd used for full path resolution
---@return snacks.picker.finder.Item
local function to_snacks_item(fff_item, cwd)
	local rel = fff_item.relative_path or ""
	local line = fff_item.line_number or 1
	local col = fff_item.column_number or 1
	local content = fff_item.line_content or ""

	return {
		-- snacks uses `file` to open the buffer; use absolute path for safety
		file = cwd .. "/" .. rel,
		-- pos is { line, col } with col 0-indexed
		pos = { line, col - 1 },
		-- `text` is what's displayed in the picker list
		text = rel .. ":" .. line .. ":" .. col .. ":" .. content,
		-- `line` is used by snacks for match highlighting
		line = content,
		-- cwd so snacks can display relative paths correctly
		cwd = cwd,
	}
end

--- Custom snacks finder that uses fff's in-process grep engine.
---@param opts table  picker opts (cwd, etc.)
---@param ctx snacks.picker.Context
---@return fun(): snacks.picker.finder.Item?
local function fff_grep_finder(opts, ctx)
	local query = ctx.filter.search

	-- Don't search on empty query
	if not query or query == "" then
		return function() end
	end

	-- Ensure fff is initialized (fff initializes lazily on first call)
	local core_ok, core = pcall(require, "fff.core")
	if not core_ok then
		vim.notify("fff.nvim not available", vim.log.levels.WARN)
		return function() end
	end
	pcall(core.ensure_initialized)

	local grep_ok, fff_grep = pcall(require, "fff.grep")
	if not grep_ok then
		vim.notify("fff.grep not available", vim.log.levels.WARN)
		return function() end
	end

	local cwd = opts.cwd or utils.get_root_dir() or vim.uv.cwd() or "."

	-- Change fff's indexing directory if it differs from current cwd.
	-- fff maintains a single indexed directory; calling change_indexing_directory
	-- triggers a re-index if the path changed.
	local fff_ok, fff = pcall(require, "fff")
	if fff_ok and fff.change_indexing_directory then
		pcall(fff.change_indexing_directory, cwd)
	end

	-- Perform the search synchronously (fff is in-process, this is fast)
	local ok, result = pcall(fff_grep.search, query, 0, MAX_RESULTS, {
		smart_case = true,
		max_matches_per_file = 200,
		time_budget_ms = 150,
	}, "plain")

	if not ok or not result or not result.items then
		return function() end
	end

	local items = result.items
	local i = 0

	-- Return a stateful iterator; snacks calls this until nil
	return function()
		i = i + 1
		local item = items[i]
		if item == nil then
			return nil
		end
		return to_snacks_item(item, cwd)
	end
end

--- Live grep from project root using fff as the backend.
--- Displays results in snacks picker with full preview support.
---@param opts? table
function M.live_grep_from_root(opts)
	opts = opts or {}
	local cwd = utils.get_root_dir()

	Snacks.picker({
		title = "FFF Grep",
		-- `finder` replaces the default rg subprocess with our fff function
		finder = fff_grep_finder,
		-- Pass cwd through opts so the finder can access it
		cwd = cwd,
		-- live = true means snacks re-runs the finder on every keystroke
		-- (this is the default for grep-style pickers)
		live = true,
		-- Use snacks' built-in grep format/preview support
		format = "grep",
		preview = "grep",
		-- Matches snacks' own grep picker behavior
		supports_live = true,
	})
end

return M
```

**Step 3: Test the module loads**

```bash
nvim --headless -c "lua require('user.snacks.fff_grep')" -c "qa" 2>&1
```

Expected: Silent (no errors).

---

## Task 4: Wire the new finder into keybindings

**Files:**
- Modify: `mods/dotfiles/nvim/lua/user/whichkey/search_snacks.lua`

The primary `<leader>hr` "grep from root" binding is the main one to update. The git-scoped greps (`hd`, `hD`, `hq`) stay on rg because they filter to specific file lists — fff doesn't support that yet.

**Step 1: Update search_snacks.lua**

Replace the existing `search_files` import and `<leader>hr` bindings with fff_grep:

```lua
-- At the top of search_snacks.lua, add:
local fff_grep = require("user.snacks.fff_grep")
```

Then replace the `<leader>hr` normal-mode binding from:
```lua
{
    "<leader>hr",
    function()
        search_files.live_grep_from_root()
    end,
    desc = "grep from (r)oot",
},
```

To:
```lua
{
    "<leader>hr",
    function()
        fff_grep.live_grep_from_root()
    end,
    desc = "fff grep from (r)oot",
},
```

And replace the visual-mode `<leader>hr` binding from:
```lua
{
    "<leader>hr",
    function()
        paste_to_search(function(opts)
            return search_files.live_grep_from_root(opts)
        end)
    end,
    desc = "grep from (r)oot",
},
```

To:
```lua
{
    "<leader>hr",
    function()
        paste_to_search(function(opts)
            return fff_grep.live_grep_from_root(opts)
        end)
    end,
    desc = "fff grep from (r)oot",
},
```

**Step 2: Verify keymap file loads**

```bash
nvim --headless -c "lua require('user.whichkey.search_snacks')" -c "qa" 2>&1
```

Expected: Silent.

---

## Task 5: Manual integration test

Open Neovim in a project directory with Lua/source files and verify:

1. Press `<leader>hr` — the snacks picker opens titled "FFF Grep"
2. Type a search term (e.g., `function`) — results appear from fff
3. Navigate results with `j`/`k`, preview panel shows the matched file
4. Press `<CR>` — jumps to the correct file and line
5. Press `<Esc>` — picker closes cleanly

Also check that the git-scoped greps still work:
- `<leader>hd` — grep in git-changed files (still uses rg, unchanged)
- `<leader>hq` — grep in quickfix list (still uses rg, unchanged)

---

## Task 6: Handle the snacks finder API correctly (likely fix needed)

> **Note:** The snacks picker `finder` API may differ from what's documented above. The exact contract needs verification against the installed snacks version. There are two patterns snacks supports:

**Pattern A — items array** (simpler, all at once):
```lua
Snacks.picker({
  items = items_table,  -- static list
  ...
})
```

**Pattern B — custom finder function** (dynamic, live):
```lua
Snacks.picker({
  finder = function(opts, ctx)
    -- Must return an async "producer" or be used differently
  end,
  ...
})
```

If Pattern B doesn't work as written in Task 3, fall back to Pattern A with a `transform` approach:

```lua
-- Alternative: override the grep source at the snacks config level
-- In snacks/init.lua, add a custom source:
Snacks.picker.sources.fff_grep = {
  finder = fff_grep_finder,
  format = "grep",
  preview = "grep",
  live = true,
  supports_live = true,
}

-- Then call it as:
Snacks.picker.fff_grep({ cwd = utils.get_root_dir() })
```

**Check the installed snacks source:**
```bash
find ~/.local/share/nvim/lazy/snacks.nvim -name "*.lua" -path "*/picker/*" | head -20
cat ~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/picker/init.lua | head -80
```

This will show the actual finder contract for the installed version.

---

## Task 7: Add Nix package for fff binary (optional but recommended)

fff.nvim downloads a prebuilt binary on first `:Lazy sync`. For a reproducible Nix setup, it's better to provide the binary via Nix rather than relying on the download step.

**Files:**
- Check: `mods/base-packages.nix` or relevant language module

**Step 1: Check if fff is in nixpkgs**

```bash
nix search nixpkgs fff 2>/dev/null | head -20
# Or check pkgs-unstable
nix eval 'github:NixOS/nixpkgs/nixpkgs-unstable#fff' --apply 'x: x.name' 2>/dev/null
```

**Step 2: If available, add to packages**

In the appropriate Nix module (e.g., `mods/base-packages.nix`):
```nix
pkgs-unstable.fff-nvim  # or whatever the package is named
```

Then validate with dry-run:
```bash
nix build .#darwinConfigurations.nicks-mbp.system --dry-run
```

> If not in nixpkgs yet, skip this task. The lazy.nvim `build` hook downloading the binary is acceptable for now. Note this in `WORKAROUNDS.md`.

---

## Troubleshooting Notes

### fff results show wrong paths
Check that `cwd` passed to `fff.change_indexing_directory` matches the project root. fff's `relative_path` is relative to its indexed base directory.

### Empty results on first search
fff indexes files asynchronously after initialization. The first search after startup may return nothing. Press `<ESC>` and try again — subsequent searches will hit the warm index. Set `lazy_sync = false` in fff.setup() if you need immediate availability (trades startup time).

### Snacks picker opens but shows no items
Enable debug in `search_snacks.lua` temporarily:
```lua
-- Before the picker call:
local ok, result = pcall(fff_grep.search, "test", 0, 10, {}, "plain")
vim.notify(vim.inspect(result), vim.log.levels.INFO)
```
This verifies fff is returning results before they reach the snacks item transformer.

### Finder API mismatch
Check the actual snacks picker source for the correct `finder` contract:
```
~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/picker/source/grep.lua
```
The finder in that file shows exactly what snacks expects.
