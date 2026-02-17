# Dotfiles Improvement Plan

## Phase 1: Code Fixes (Non-Logical Only)

All changes below are provably non-logical: dead code removal, deprecated API replacement,
typo/bug fixes, and naming convention normalization. No behavioral changes.

---

### 1. Nix Fixes

#### 1a. Remove `nixhub_dep` duplicate (replace with `pkgs-unstable`)

`nixhub_dep` in `lib/builders.nix` is `import nixpkgs { inherit system; config.allowUnfree = true; }`
which is identical to `pkgs-unstable`. The only consumer is `mods/gh.nix`.

**`lib/builders.nix`** -- Remove lines 9-12 and line 15-17:
```nix
# REMOVE these lines:
    nixhub_dep = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    # ...
    customPackages = {
      inherit (inputs) procmux proctmux secret_inject animal_rescue scrollbacktamer rift;
    };
```

**`mods/gh.nix`** -- Replace `nixhub_dep` with `pkgs-unstable`:
```nix
# FROM:
{ pkgs, pkgs-unstable, nixhub_dep, ... }: {
  programs.gh = {
    enable = true;
    extensions = [  nixhub_dep.gh-actions-cache ];
  };
}

# TO:
{ pkgs, pkgs-unstable, ... }: {
  programs.gh = {
    enable = true;
    extensions = [ pkgs-unstable.gh-actions-cache ];
  };
}
```

#### 1b. Remove unused `nil` flake input

**`flake.nix`** -- Remove line 18:
```nix
# REMOVE:
    nil.url = "github:oxalica/nil";
```
Then run `nix flake lock` to clean the lockfile.

#### 1c. Fix `autoSquash` typo in git config

**`mods/git.nix`** line 26:
```nix
# FROM:
        autoSqaush = true;
# TO:
        autoSquash = true;
```

#### 1d. Fix `allowUnfree` case in supermicro config

**`homes/home-supermicro.nix`** lines 21-23:
```nix
# FROM:
      allowunfree = true;
      allowunfreepredicate = (_: true);
# TO:
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
```

#### 1e. DRY shell.nix opencode symlinks

**`mods/shell.nix`** -- Extract a helper to reduce the 12 repetitive symlink entries.
Add at the top of the let block:
```nix
  mkSym = path: config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles/${path}";
```
Then replace all the repeated `config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles/..."` calls with `mkSym "..."`.

For example:
```nix
# FROM:
    ".config/opencode/config.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles/opencode-config.json";
# TO:
    ".config/opencode/config.json".source = mkSym "opencode-config.json";
```

Apply this to all mkOutOfStoreSymlink entries that follow the pattern. The symlinks themselves are unchanged -- only the Nix expression is DRYer.

---

### 2. Neovim: Replace Deprecated APIs

#### 2a. Replace `vim.api.nvim_set_keymap` with `vim.keymap.set`

**`lua/user/keymaps.lua`**:
```lua
-- FROM (lines 1-9, 22-23, 43-44, 47):
local opts = { noremap = true, silent = true }
local term_opts = { silent = true }
local keymap = vim.api.nvim_set_keymap
keymap("", "<Space>", "<Nop>", opts)
-- ...
keymap("n", "<S-l>", ":bnext<CR>", opts)
keymap("n", "<S-h>", ":bprevious<CR>", opts)
-- ...
keymap("n", "<C-_>", ":Commentary<CR>", opts)
keymap("v", "<C-_>", ":Commentary<CR>", opts)
keymap("n", "gw", ':call feedkeys("\\<lt>c-w>")<cr>', opts)

-- TO:
local opts = { noremap = true, silent = true }

vim.keymap.set("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
-- Remove maplocalleader here (set in lazy.lua)

vim.keymap.set("n", "<S-l>", ":bnext<CR>", opts)
vim.keymap.set("n", "<S-h>", ":bprevious<CR>", opts)

vim.keymap.set("n", "<C-_>", ":Commentary<CR>", opts)
vim.keymap.set("v", "<C-_>", ":Commentary<CR>", opts)

vim.keymap.set("n", "gw", ':call feedkeys("\\<lt>c-w>")<cr>', opts)
```

Also replace `noop` function with `"<Nop>"` string:
```lua
-- FROM (lines 51-52):
local noop = function() end
vim.keymap.set({ "n", "x", "o" }, "s", noop, { silent = true })
-- TO:
vim.keymap.set({ "n", "x", "o" }, "s", "<Nop>", { silent = true })
```

#### 2b. Replace `vim.diagnostic.goto_next` (deprecated in 0.11)

**`lua/user/lsp/keymaps.lua`** line 44:
```lua
-- FROM:
	{ key = "]d", action = vim.diagnostic.goto_next, desc = "Next diagnostic" },
-- TO:
	{ key = "]d", action = function() vim.diagnostic.jump({ count = 1, float = true }) end, desc = "Next diagnostic" },
```

#### 2c. Replace `vim.lsp.get_client_by_id` (deprecated in 0.11)

**`lua/user/lsp/init.lua`** line 17:
```lua
-- FROM:
		local client = vim.lsp.get_client_by_id(client_id)
-- TO:
		local client = vim.lsp.get_clients({ id = client_id })[1]
```

**`lua/user/lsp/attach.lua`** line 44:
```lua
-- FROM:
			local client = vim.lsp.get_client_by_id(ev.data.client_id)
-- TO:
			local client = vim.lsp.get_clients({ id = ev.data.client_id })[1]
```

#### 2d. Replace `vim.api.nvim_buf_get_option` (deprecated in 0.10)

**`lua/user/whichkey/whichkey.lua`** line 115:
```lua
-- FROM:
	if vim.api.nvim_buf_get_option(bufnr, "buftype") ~= "" then
-- TO:
	if vim.bo[bufnr].buftype ~= "" then
```

---

### 3. Neovim: Remove Dead Code

#### 3a. Remove dead nvim-cmp autocmd

**`lua/user/autocommands.lua`** -- Remove lines 59-67:
```lua
-- REMOVE (blink.cmp is the completion engine, not nvim-cmp):
-- dadbod - enable auto complete for table names and other db assets
vim.api.nvim_create_autocmd("FileType", {
	desc = "dadbod completion",
	group = vim.api.nvim_create_augroup("dadbod_cmp", { clear = true }),
	pattern = { "sql", "mysql", "plsql" },
	callback = function()
		require("cmp").setup.buffer({ sources = { { name = "vim-dadbod-completion" } } })
	end,
})
```

#### 3b. Remove dead alpha augroup

**`lua/user/autocommands.lua`** -- Remove lines 29-32:
```lua
-- REMOVE (alpha-nvim not installed, snacks dashboard used):
  augroup _alpha
    autocmd!
    autocmd User AlphaReady set showtabline=0 | autocmd BufUnload <buffer> set showtabline=2
  augroup end
```

#### 3c. Remove unused `lsp_mason` import

**`lua/user/autocommands.lua`** -- Remove line 41:
```lua
-- REMOVE:
local lsp_mason = require("user.lsp.mason")
```

#### 3d. Remove unused `term_opts` variable

**`lua/user/keymaps.lua`** -- Remove line 3:
```lua
-- REMOVE:
local term_opts = { silent = true }
```

#### 3e. Remove dead `biome_enabled` variable

**`lua/user/lsp/mason.lua`** -- Remove line 14:
```lua
-- REMOVE:
local biome_enabled = utils.table_has_value(project_lint_config, "biome")
```

#### 3f. Remove dead `client_to_fix_import_fns` and `fix_all_imports`

**`lua/user/lsp/mason.lua`** -- Remove lines 46-58:
```lua
-- REMOVE (empty table, never populated, call site commented out):
local client_to_fix_import_fns = {}

M.fix_all_imports = function()
	local active_clients = vim.lsp.get_clients()
	for _, client in ipairs(active_clients) do
		local client_name = client.name
		local fn = client_to_fix_import_fns[client_name]
		if fn then
			fn()
		end
	end
end
```

#### 3g. Fix shadowed `status_ok` variable

**`lua/user/lsp/mason.lua`** lines 1-9:
```lua
-- FROM:
local status_ok, mason = pcall(require, "mason")
if not status_ok then
	vim.notify("mason not found")
	return
end
local status_ok, mason_lspconfig = pcall(require, "mason-lspconfig")
-- TO:
local mason_ok, mason = pcall(require, "mason")
if not mason_ok then
	vim.notify("mason not found")
	return
end
local mason_lsp_ok, mason_lspconfig = pcall(require, "mason-lspconfig")
if not mason_lsp_ok then
	vim.notify("mason-lspconfig not found")
	return
end
```

---

### 4. Neovim: Bug Fixes and Modernization

#### 4a. Fix `maplocalleader` race condition

**`lua/user/keymaps.lua`** -- Remove line 11:
```lua
-- REMOVE (lazy.lua sets it to ";" which is the intended value):
vim.g.maplocalleader = " "
```

#### 4b. Fix codecompanion double-setup

**`lua/user/lazy.lua`** line 197:
```lua
-- FROM:
		"olimorris/codecompanion.nvim",
		config = true,
-- TO:
		"olimorris/codecompanion.nvim",
```
(Remove `config = true` so only the plugin registry's `setup()` call applies)

#### 4c. Fix dadbod `opt = true`

**`lua/user/lazy.lua`** line 232:
```lua
-- FROM:
		"tpope/vim-dadbod",
		opt = true,
-- TO:
		"tpope/vim-dadbod",
		lazy = true,
```
(Note: `cmd = {...}` already provides lazy loading, so `lazy = true` is technically redundant but semantically correct unlike `opt`)

#### 4d. Fix file handle leak

**`lua/user/utils/file_utils.lua`** lines 35-44:
```lua
-- FROM:
function M.read_file_to_string(filename)
	if not M.file_exists(filename) then
		return nil
	end
	local path = io.open(filename, "r")
	if path ~= nil then
		return path:read("*a")
	end
	return nil
end

-- TO:
function M.read_file_to_string(filename)
	if not M.file_exists(filename) then
		return nil
	end
	local fh = io.open(filename, "r")
	if fh ~= nil then
		local content = fh:read("*a")
		fh:close()
		return content
	end
	return nil
end
```

#### 4e. Replace `vim.fn.json_decode` with `vim.json.decode`

**`lua/user/utils/file_utils.lua`** lines 15, 32:
```lua
-- FROM:
	local json = vim.fn.json_decode(contents)
-- TO:
	local json = vim.json.decode(contents)
```
(Apply to both occurrences)

#### 4f. Replace VimScript Format command with Lua API

**`lua/user/lsp/init.lua`** line 179:
```lua
-- FROM:
vim.cmd([[ command! Format execute 'lua vim.lsp.buf.format{async=true}' ]])
-- TO:
vim.api.nvim_create_user_command("Format", function()
	vim.lsp.buf.format({ async = true })
end, {})
```

---

### 5. Karabiner: Dead Code Removal

#### 5a. Delete `hyper.ts`

```bash
rm mods/dotfiles/karabiner/src/hyper.ts
```
Never imported by `index.ts`. Alternative implementation superseded by `cap-modifier.ts`.

#### 5b. Delete `system-leader.ts`

```bash
rm mods/dotfiles/karabiner/src/system-leader.ts
```
Import is commented out in `index.ts`. Leader system is disabled.

#### 5c. Remove phantom `windowLeaderRules` comment from `index.ts`

**`mods/dotfiles/karabiner/src/index.ts`** -- Remove the commented-out line referencing
the non-existent `windowLeaderRules`:
```ts
// REMOVE:
// ...windowLeaderRules,
```

#### 5d. Simplify `leader-utils.ts`

Remove dead exports that were only used by the deleted `system-leader.ts`:
- Remove `windowLeader` export
- Remove `allKeyCodes` export
- Remove `LeaderNode` type export
- Remove `buildLeaderManipulators` function
- Remove `buildLeaderKeyRule` function

Keep only:
- `systemLeader` constant (used by `exitLeader`)
- `exitLeader()` function (used by `cap-modifier.ts`)

The file should be reduced to roughly:
```ts
import { toSetVar } from "karabiner.ts";
import type { ToEvent } from "karabiner.ts";

export const systemLeader = "system_leader";

export function exitLeader(): ToEvent[] {
  return [toSetVar(systemLeader, 0)];
}
```

#### 5e. Rename `modifierSwap.ts` to `modifier-swap.ts`

```bash
mv mods/dotfiles/karabiner/src/modifierSwap.ts mods/dotfiles/karabiner/src/modifier-swap.ts
```

Update import in `index.ts`:
```ts
// FROM:
import { modifierSwapRules } from "./modifierSwap.ts";
// TO:
import { modifierSwapRules } from "./modifier-swap.ts";
```

#### 5f. Rebuild karabiner.json after changes

```bash
cd mods/dotfiles/karabiner && deno task build
```

---

## Phase 2: Documentation & Skills

### 6. Rewrite Root AGENTS.md

Add these sections to the existing AGENTS.md:

- **Machine Inventory**: List all 4 machines with hostnames, architectures, and valid build commands
- **Builder Pattern**: Explain `lib/builders.nix` `mkDarwinSystem`/`mkNixOSSystem` and how they wire profiles
- **Profile Layering**: `darwin-base -> darwin-{personal,work,maclab}` + `common -> darwin -> per-machine`
- **Symlink Strategy**: Explain `mkOutOfStoreSymlink` and when rebuild is/isn't needed (user preference)
- **Cross-Cutting Concerns**: Language packages shared between shell and neovim
- **Activation Hooks**: `uvx.nix` and `npmx.nix` patterns
- **Common Gotchas**: Don't edit generated karabiner.json, Deno/vtsls mutual exclusion, etc.

Update Neovim section with:
- **Dual LSP Architecture**: `lsp/` (vim.lsp.config) vs `lua/user/lsp/` (orchestration)
- **Snacks.nvim**: Replace any telescope references
- **Plugin Registry**: More detail on the registry pattern
- **EFM Auto-Detection**: eslint vs biome vs deno_fmt logic
- **Project-Local Config**: `.nvim.lua` exrc system

Update Karabiner section with:
- **Active vs Inactive modules**: Clarify which files are active
- **Layer inventory**: Document what each layer does

### 7. Rewrite `mods/dotfiles/nvim/AGENTS.md`

Rewrite to accurately describe the current architecture with:
- Correct file paths (utils/ not _file_utils.lua, snacks/ not telescope)
- Dual LSP architecture explanation
- Which-key aggregation pattern
- Plugin registry system (already good, keep)
- Snacks picker system
- AI plugin landscape (copilot, codecompanion, opencode, sidekick)

### 8. Rewrite Neovim Skill

Replace `.agents/skills/neovim/SKILL.md` with one that accurately describes THIS config:
- Dynamic references: "Read `plugin_registry.lua` for current plugin list"
- Architecture patterns specific to this config
- Correct keybinding prefixes
- Snacks.nvim instead of telescope
- Kanagawa instead of tokyonight
- `lua/user/` instead of `lua/config/`

Rewrite key reference files:
- `references/configuration.md` -- actual init flow, options, lazy.lua structure
- `references/plugins.md` -- actual plugin categories from registry
- `references/lsp.md` -- dual LSP architecture, EFM config, mason setup
- `references/keybindings.md` -- actual which-key prefixes and mappings

### 9. Enhance Nix Best Practices Skill

Add project-specific section to `.agents/skills/nix-best-practices/SKILL.md`:
- Builder pattern example from this project
- Profile layering explanation
- `mkOutOfStoreSymlink` usage patterns
- Activation hook patterns (uvx.nix, npmx.nix)
- How language modules are organized and shared
- Known improvement opportunities (follows, useGlobalPkgs, etc.)

### 10. Create Karabiner Skill

Create `.agents/skills/karabiner/SKILL.md` covering:
- karabiner.ts library API basics
- This project's layer architecture (caps-layer, simlayers, tab-window)
- Build workflow (deno task build -> reload)
- How to add new rules
- Active vs inactive modules
- Variable-based layer system vs hyper modifier approach

### 11. Update Subagent Definitions

**`.opencode/agent/neovim.md`**:
- Add instruction to read `plugin_registry.lua`
- Mention snacks.nvim as picker framework
- Reference the dual LSP architecture
- Add which-key aggregation pattern note

**`.opencode/agent/nix.md`**:
- Add machine names for build commands
- Reference `lib/builders.nix` for architecture
- Note the symlink strategy preference

---

## Phase 3: Additional Cleanup (Non-Logical)

All completed in second pass.

### Neovim: Dead File Removal

- **Deleted `lua/user/core/keymaps.lua`** -- Never required by init.lua (loads `user.keymaps`). Old copy with deprecated APIs.
- **Deleted `lua/user/core/options.lua`** -- Byte-identical duplicate of `user/options.lua`. Never required.
- **Deleted empty `lua/user/core/` directory** -- Both files removed, directory empty.
- **Deleted `lua/user/github-search.lua`** -- Commented out in init.lua, references uninstalled `nvim-github-codesearch` plugin.
- **Deleted `lua/user/diff.lua`** -- Duplicate of `plugins/git/diff.lua` (registered in plugin_registry). Commands were registered twice at runtime.
- **Removed `require("user.diff")` and github-search comment from `init.lua`**

### Neovim: Bug Fixes

- **Fixed broken pcall guard in `plugins/ai/codecompanion.lua:5`** -- Changed `if not codecompanion` to `if not ok`. The original guard never triggered on failure because pcall returns error string (truthy) as second value on failure.
- **Fixed `io.popen` handle leak in `utils/git_utils.lua:37`** -- Added `handle:close()` after `handle:read("*a")`.
- **Replaced deprecated `nvim_buf_get_option` in `plugins/ui/lualine.lua:65`** -- Changed to `vim.bo[0].shiftwidth`. Last remaining instance in codebase.
- **Removed unused `start_line`/`end_line` variables in `plugins/git/diff.lua:312-313`**
- **Fixed "the the" typo in `plugins/git/diff.lua:44`** comment

### Nix: Unused Arguments and Dead Code

- **Removed unused `procmux`, `secret_inject` from `mods/system-packages.nix` signature**
- **Removed unused `procmux`, `secret_inject`, `animal_rescue` from `mods/ui-packages.nix` signature**
- **Removed no-op `with pkgs-unstable;` from `mods/languages/all.nix:22`** -- No unqualified attribute used.
### Documentation: Skill Files

- **Rewrote `.agents/skills/skill-neovim-research/SKILL.md`** -- Replaced all `lua/neotex/` paths with correct `lua/user/` paths, removed references to non-existent `.claude/` directories and `nvim/tests/`, updated plugin references (snacks instead of telescope), added modern API requirements.
- **Rewrote `.agents/skills/skill-neovim-implementation/SKILL.md`** -- Same path corrections, fixed indent setting from "2 spaces" to "tabs (stylua)", updated module template to match actual codebase patterns, added pcall guard warning about checking `ok` not module value.

---

## Phase 4: Additional Cleanup (Non-Logical)

All completed in third pass.

### Neovim: Dead Code Removal

- **Removed dead `setup.commands.Format` block from `lsp/jsonls.lua:186-194`** -- `setup.commands` was an lspconfig-specific feature; this file is a native `vim.lsp.config()` server config, so the block was ignored. Also contained deprecated `vim.lsp.buf.range_formatting` (removed in 0.10).
- **Deleted entirely-commented `lsp/sqlls.lua`** -- All 13 lines were comments. Not enabled in `vim.lsp.enable()`.

### Nix: Dead Code

- **Removed unused `cursorAgent` variable from `mods/base-packages.nix:15`** -- Assigned via `callPackage` but only referenced in a comment. Caused unnecessary derivation evaluation on every build. Also removed the `# cursorAgent` comment.

### Typo Fixes

- **`mods/shell.nix:125`** -- "becahse" -> "because"
- **`mods/shell.nix:126`** -- ".baskrc" -> ".bashrc"
- **`readme.md:85`** -- "connfiguration" -> "configuration"
- **`mods/dotfiles/nvim/readme.md:70`** -- "annoations" -> "annotations"

### Documentation Updates

- **`readme.md:59-67`** -- Removed stale step 10 about `nvim-github-codesearch` installation (references packer path, plugin no longer installed)
- **`mods/dotfiles/nvim/readme.md`** -- Updated stale references:
  - `:NullLsInfo` -> `:EfmLangServerInfo` (EFM is used, not null-ls)
  - `:DiffViewOpen`/`:DiffViewClose` -> `:CodeDiff` commands (CodeDiff is used, not diffview)
  - `diffview` -> `codediff` in plugin directory listing
  - Example keymap updated from `DiffviewOpen` to `CodeDiff`

---

## Notes for Future Sessions (Not in Scope)

These items were identified but require logic changes or testing:

- Convert VimScript autocommands to Lua API (`autocommands.lua:3-39`)
- Replace `io.popen` with `vim.system` in `git_utils.lua` and `file_utils.lua`
- Replace `lspconfig.util.root_pattern` with `vim.fs.root` in `file_utils.lua`
- Remove `vim-commentary` in favor of Neovim 0.10+ built-in commenting
- Add `nixpkgs.follows` to `proctmux`, `secret_inject`, `animal_rescue`, `scrollbacktamer` inputs
- Consolidate `home-supermicro.nix` to use common.nix profile
- Refactor `window-layer.ts` to use `withCondition()` for DRYer Karabiner config
- Refactor `cap-modifier.ts` to use karabiner.ts fluent API consistently
- Remove duplicate blink.cmp config (blink.lua vs plugins/code/blink.lua)
- Extract embedded Python script from `window-layer.ts`
- Address `lazyredraw` conflict with async UI plugins
- Replace `PlenaryJob` with `vim.system` in git_utils.lua
- Add `pcall` guards to unprotected requires in `snacks/ai_context_files.lua:1-4`
- Deduplicate database keymaps (inline in `whichkey.lua:32-38` vs `plugins/database/dadbod.lua` get_keymaps)
- Deduplicate debug keymaps (inline in `whichkey.lua:283-305` vs `plugins/debug/nvim-dap.lua` get_keymaps)
- Remove unused `hostname` parameter from `mkDarwinSystem`/`mkNixOSSystem` in `lib/builders.nix`
- Remove unused named args from `homes/home-nicks-mbp.nix` and `homes/home-maclab.nix` signatures
- Remove `systemLeader` export from `karabiner/src/leader-utils.ts` (only used internally)
