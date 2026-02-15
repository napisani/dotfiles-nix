---
name: neovim
description: Guide for this Neovim configuration -- a modular Lua-based IDE rooted at mods/dotfiles/nvim/. Use when configuring plugins, adding keybindings, setting up LSP servers, debugging, or extending the config. Covers lazy.nvim, plugin_registry, snacks.nvim pickers, blink.cmp completion, dual LSP architecture, DAP debugging, and which-key v3 aggregation.
---

# Neovim Configuration Skill

Guide for working with this modular Neovim configuration. The config lives at `mods/dotfiles/nvim/` within the home-manager flake and is symlinked to `~/.config/nvim/` via `mkOutOfStoreSymlink` (edits take effect immediately without Nix rebuild).

## Quick Reference

| Aspect | Value |
|--------|-------|
| Plugin Manager | lazy.nvim (bootstrapped in `lua/user/lazy.lua`) |
| Module Pattern | `M.setup()` + optional `M.get_keymaps()` |
| Leader Key | `<Space>` (`<localleader>` = `;`) |
| Colorscheme | kanagawa.nvim |
| Picker Framework | snacks.nvim (NOT telescope) |
| Completion Engine | blink.cmp (NOT nvim-cmp) |
| File Explorer | nvim-tree (NOT neo-tree) |
| Formatter Engine | EFM LSP (format-on-save via `BufWritePost`) |

## Architecture Overview

```
mods/dotfiles/nvim/
├── init.vim                      # Bootstrap: sets termguicolors, loads user.init
├── lazy-lock.json                # Plugin version lock
├── lsp/                          # Native vim.lsp.config() server configs (Neovim 0.11+)
│   ├── basedpyright.lua          #   Each file returns a config table
│   ├── denols.lua
│   ├── efm.lua                   #   EFM formatter/linter config (read for language map)
│   ├── gopls.lua
│   ├── lua_ls.lua
│   ├── vtsls.lua
│   └── ...                       #   Read lsp/ directory for current server list
├── lua/user/
│   ├── init.lua                  # Main entry point (initialization order)
│   ├── options.lua               # Vim options
│   ├── keymaps.lua               # Base keymaps (non-which-key)
│   ├── autocommands.lua          # Autocommands (format-on-save, filetype, etc.)
│   ├── lazy.lua                  # lazy.nvim bootstrap + all plugin specs
│   ├── plugin_registry.lua       # Ordered list of plugin modules (single source of truth)
│   ├── blink.lua                 # blink.cmp opts (referenced by lazy.lua)
│   ├── trouble.lua               # trouble.nvim opts (referenced by lazy.lua)
│   ├── diff.lua                  # Non-modular plugin (legacy)
│   ├── lsp/
│   │   ├── init.lua              # vim.lsp.enable() calls + diagnostics config
│   │   ├── mason.lua             # Mason setup + ensure_installed servers
│   │   ├── attach.lua            # LspAttach autocmd (wires keymaps per-buffer)
│   │   ├── keymaps.lua           # Base LSP keymaps + per-server keymaps
│   │   └── actions.lua           # LSP code actions (organize imports, etc.)
│   ├── plugins/                  # Plugin config modules (category/name.lua)
│   │   ├── ai/                   #   Read plugin_registry.lua for current module list
│   │   ├── code/
│   │   ├── database/
│   │   ├── debug/
│   │   ├── editing/
│   │   ├── git/
│   │   ├── navigation/
│   │   ├── ui/
│   │   └── util/
│   ├── whichkey/
│   │   ├── whichkey.lua          # Main aggregator (combines all keymaps)
│   │   ├── plugins.lua           # Auto-discovers keymaps from registry modules
│   │   ├── find_snacks.lua       # <leader>f -- file/buffer finders
│   │   ├── search_snacks.lua     # <leader>h -- grep/search
│   │   ├── replace.lua           # <leader>r -- find & replace
│   │   ├── repl.lua              # REPL/slime keymaps
│   │   ├── scopes.lua            # Scope-related keymaps
│   │   ├── lsp.lua               # LSP-related which-key groups
│   │   └── global.lua            # Global/misc keymaps
│   ├── snacks/                   # Custom snacks.nvim pickers
│   │   ├── init.lua              # Snacks opts (dashboard, picker, notifier, etc.)
│   │   ├── find_files.lua        # File finding pickers
│   │   ├── search_files.lua      # Grep/search pickers
│   │   ├── git_files.lua         # Git changed/conflicted file pickers
│   │   ├── git_search.lua        # Grep within git-changed files
│   │   ├── scope.lua             # Scope picker
│   │   ├── compare.lua           # Compare picker
│   │   ├── common.lua            # Shared picker utilities
│   │   ├── ai_actions.lua        # AI action pickers
│   │   ├── ai_context_files.lua  # AI context file pickers
│   │   ├── proctmux.lua          # Proctmux command picker
│   │   └── commands/             # Command launcher categories
│   │       ├── init.lua          # Aggregates all command categories
│   │       ├── ai.lua
│   │       ├── finders.lua
│   │       ├── lsp.lua
│   │       ├── package_manage.lua
│   │       └── project.lua
│   ├── dap/                      # Per-language DAP configurations
│   │   ├── go.lua
│   │   ├── python.lua
│   │   └── typescript.lua
│   ├── utils/                    # Utility modules
│   │   ├── init.lua
│   │   ├── file_utils.lua
│   │   ├── git_utils.lua
│   │   ├── project_utils.lua
│   │   └── collection_utils.lua
│   └── core/                     # Core option/keymap modules
│       ├── options.lua
│       └── keymaps.lua
```

> **Dynamic note**: Read the actual files for current state. The tree above is a structural guide -- files may be added or removed over time.

## Initialization Order

Read `lua/user/init.lua` for the definitive boot sequence. The general flow is:

```
init.vim
  -> require("user.init")
    -> exrc_manager.source_local_config()   -- .nvim.lua project config (early)
    -> require("user.options")
    -> require("user.keymaps")
    -> require("user.lazy")                 -- lazy.nvim bootstrap + plugin specs
    -> require("user.lsp")                  -- mason, attach, vim.lsp.enable()
    -> plugin_registry loop                 -- setup() on each registered module
    -> require("user.whichkey.whichkey")    -- aggregates all keymaps
    -> require("user.autocommands")
    -> require("user.diff")                 -- non-modular legacy plugin
    -> exrc_manager.setup()                 -- finalize project config (late)
```

## Standard Module Pattern

Plugin modules live in `lua/user/plugins/<category>/<name>.lua`. Each module follows this pattern:

```lua
local M = {}

function M.setup()
  local ok, plugin = pcall(require, "plugin-name")
  if not ok then
    vim.notify("plugin-name not found")
    return
  end

  plugin.setup({
    -- configuration
  })
end

-- Optional: keymaps are auto-discovered by whichkey/plugins.lua
function M.get_keymaps()
  return {
    shared = {
      { "<leader>x", group = "Group Name" },
    },
    normal = {
      { "<leader>xx", "<cmd>Command<cr>", desc = "Description" },
    },
    visual = {
      { "<leader>xx", "<cmd>Command<cr>", desc = "Description" },
    },
  }
end

return M
```

Key points:
- `M.setup()` is called during init by the registry loop in `lua/user/init.lua`
- `M.get_keymaps()` is optional -- if present, `whichkey/plugins.lua` auto-discovers and registers the keymaps
- Always use `pcall` when requiring plugins that might not be installed
- The return table must have `shared`, `normal`, and/or `visual` keys for keymap mode routing

> **Read** `lua/user/plugins/ui/colorscheme.lua` or `lua/user/plugins/debug/nvim-dap.lua` for real working examples of this pattern.

## Plugin Management

### How Plugins Are Configured

This config separates plugin **installation** from plugin **configuration**:

1. **`lua/user/lazy.lua`** -- All plugin specs (installation, dependencies, lazy-loading). This is the `require("lazy").setup({ spec = { ... } })` call.
2. **`lua/user/plugin_registry.lua`** -- Ordered list of module paths that get `setup()` called during init. This controls **load order** and **keymap discovery**.
3. **`lua/user/plugins/<category>/<name>.lua`** -- The actual configuration module with `M.setup()` and optional `M.get_keymaps()`.

### Adding a New Plugin

1. **Add the plugin spec** to `lua/user/lazy.lua`:
   ```lua
   { "author/plugin-name", event = "VeryLazy" },
   ```

2. **Create a config module** at `lua/user/plugins/<category>/<name>.lua` following the standard module pattern above. Categories: `ai`, `code`, `database`, `debug`, `editing`, `git`, `navigation`, `ui`, `util`.

3. **Register in `lua/user/plugin_registry.lua`** -- add `"<category>.<name>"` to `M.modules` in the appropriate position:
   ```lua
   M.modules = {
     "ui.notify",       -- must load early
     "ui.colorscheme",  -- must load early
     -- ...
     "<category>.<name>",  -- add in logical position
   }
   ```

> **IMPORTANT**: Load order matters. UI plugins (colorscheme, notify) must load first. Read `plugin_registry.lua` for current ordering.

### Plugin Commands

| Command | Description |
|---------|-------------|
| `:Lazy` | Open lazy.nvim dashboard |
| `:Lazy sync` | Update and install plugins |
| `:Lazy profile` | Startup time analysis |
| `:Lazy clean` | Remove unused plugins |

## LSP Configuration

This config uses a **dual LSP architecture** taking advantage of Neovim 0.11+'s native `vim.lsp.config()`.

### Architecture

```
Top-level lsp/ directory          lua/user/lsp/ directory
(server configs)                  (orchestration)
─────────────────                 ────────────────────────
lsp/gopls.lua                     lua/user/lsp/init.lua    -- vim.lsp.enable() + diagnostics
lsp/lua_ls.lua                    lua/user/lsp/mason.lua   -- mason setup + ensure_installed
lsp/efm.lua                       lua/user/lsp/attach.lua  -- LspAttach autocmd
lsp/vtsls.lua                     lua/user/lsp/keymaps.lua -- base + per-server keymaps
lsp/denols.lua                    lua/user/lsp/actions.lua -- code actions (organize imports)
lsp/basedpyright.lua
lsp/...
```

**Server config files** (`lsp/<name>.lua`) return a table consumed by `vim.lsp.config()`:
```lua
return {
  root_markers = { "go.mod", "go.work" },
  settings = {
    gopls = {
      analyses = { unusedparams = true },
    },
  },
}
```

**Orchestration** (`lua/user/lsp/init.lua`) calls `vim.lsp.enable()` for each server and configures diagnostics.

### Adding a New LSP Server

1. **Create config file** at `lsp/<servername>.lua`:
   ```lua
   return {
     root_markers = { "marker_file" },
     settings = {
       -- server-specific settings
     },
   }
   ```

2. **Add to `vim.lsp.enable()`** in `lua/user/lsp/init.lua`

3. **Add to mason `ensure_installed`** in `lua/user/lsp/mason.lua` (the `servers` list)

4. **Optionally add per-server keymaps** in `lua/user/lsp/keymaps.lua` under `M.per_server`

> **Read** `lua/user/lsp/init.lua` for the current list of enabled servers and the deno/vtsls mutual exclusion logic.

### Deno vs TypeScript Detection

`lua/user/lsp/init.lua` checks for `deno.json`/`deno.jsonc` at startup:
- Present: enables `denols`, skips `vtsls`
- Absent: enables `vtsls`, skips `denols`

These are mutually exclusive to avoid conflicts.

### EFM Format-on-Save

EFM LSP handles formatting and linting. Configuration is in `lsp/efm.lua`.

**How it works**:
- `autocommands.lua` has a `BufWritePost` autocmd that calls `vim.lsp.buf.format({ name = "efm" })`
- EFM auto-detects formatters per project context:
  - `deno.json` present -> `deno_fmt`
  - `biome.json` / `rome.json` present -> `biome`
  - Otherwise -> `eslint_d` (lint + format)
- Can be overridden via `.nvim.lua` project config (`lint` table in `_G.EXRC_M`)

> **Read** `lsp/efm.lua` for the complete language-to-formatter/linter mapping. It covers Go, Nix, shell, JS/TS, Lua, JSON, Python, Java, Gleam, Elixir, and more.

### LSP Keymaps

Base LSP keymaps are defined in `lua/user/lsp/keymaps.lua` and applied per-buffer on `LspAttach`. Read that file for the current mappings. Key ones include:

- `gd` -- go to definition
- `gr` -- references
- `gl` -- line diagnostics (float)
- `<leader>lr` -- rename
- `<leader>la` -- code action (via tiny-code-action)
- `<leader>lf` -- format (via EFM)
- `<leader>ll` -- run codelens

Per-server keymaps (e.g., `<leader>li` for organize imports on gopls/vtsls) are in `M.per_server`.

## Keybindings

### Which-Key Aggregation

Keymaps are aggregated from multiple sources in `lua/user/whichkey/whichkey.lua`:

1. **Whichkey category files** -- `find_snacks.lua`, `search_snacks.lua`, `replace.lua`, `repl.lua`, `scopes.lua`, `lsp.lua`, `global.lua`
2. **Plugin auto-discovery** -- `whichkey/plugins.lua` iterates `plugin_registry.lua` modules and collects `get_keymaps()` from any module that exports it
3. **Inline mappings** -- defined directly in `whichkey.lua` (root, database, debug, buffers, lazy/system, etc.)

> **IMPORTANT**: To understand current keybindings, read the `lua/user/whichkey/` files directly. Do NOT hardcode keymap lists -- they change frequently.

### Leader Key Prefixes

| Prefix | Category | Source File |
|--------|----------|-------------|
| `<leader>f` | Find (files, buffers, pickers) | `whichkey/find_snacks.lua` |
| `<leader>h` | Search (grep, symbols) | `whichkey/search_snacks.lua` |
| `<leader>r` | Replace | `whichkey/replace.lua` |
| `<leader>l` | LSP | `whichkey/lsp.lua` + `lsp/keymaps.lua` |
| `<leader>d` | Debug | `whichkey/whichkey.lua` (inline) |
| `<leader>b` | Buffers | `whichkey/whichkey.lua` (inline) |
| `<leader>D` | Database | `whichkey/whichkey.lua` (inline) |
| `<leader>P` | Lazy/System | `whichkey/whichkey.lua` (inline) |
| `<leader>g` | Git | Read `whichkey/global.lua` |
| `<leader>a` | AI | Read `whichkey/global.lua` + plugin modules |

> Read the specific files listed above for current mappings within each prefix.

## Debugging (DAP)

### Setup

DAP is configured in `lua/user/plugins/debug/nvim-dap.lua`. It sets up:
- `nvim-dap` core
- `nvim-dap-ui` (auto-opens/closes on debug sessions)
- `nvim-dap-virtual-text` (inline variable values)

### Language Configs

Per-language debug configurations live in `lua/user/dap/`:
- `go.lua` -- Go (delve)
- `python.lua` -- Python
- `typescript.lua` -- TypeScript/JavaScript (Chrome, Node)

> Read these files for current adapter configurations and launch profiles.

### DAP Keymaps

DAP keymaps are defined both in `whichkey.lua` (inline `debugging` table) and in the nvim-dap module's `get_keymaps()`. All under `<leader>d`. Read `lua/user/plugins/debug/nvim-dap.lua` for the current list.

## Snacks.nvim Pickers

Snacks.nvim replaces telescope as the picker framework. Custom pickers live in `lua/user/snacks/`.

### Picker Modules

| Module | Purpose |
|--------|---------|
| `find_files.lua` | File finding, path files, explorer tree toggle |
| `search_files.lua` | Live grep, grep from root, grep quickfix list |
| `git_files.lua` | Git changed files, conflicted files, branch diff files |
| `git_search.lua` | Grep within git-changed files |
| `scope.lua` | Scope-based picking |
| `compare.lua` | Comparison picker |
| `ai_actions.lua` | AI action picker (delegates to provider-specific modules) |
| `ai_context_files.lua` | AI context file selection |
| `proctmux.lua` | Proctmux/procmux command picker |
| `common.lua` | Shared utilities (`paste_to_pattern`, `paste_to_search`) |

### Command Launcher

`lua/user/snacks/commands/init.lua` aggregates command categories into a unified launcher accessible via `<leader>fl`. Categories are defined in separate files:
- `ai.lua` -- AI-related commands
- `finders.lua` -- Finder commands
- `lsp.lua` -- LSP commands
- `package_manage.lua` -- Package management commands
- `project.lua` -- Project commands

> Read `lua/user/snacks/commands/` for the current command list. Read `lua/user/snacks/init.lua` for snacks.nvim configuration (picker layout, dashboard, notifier, etc.).

## Project-Specific Configuration

`.nvim.lua` files in project roots are loaded via `exrc_manager` (`lua/user/plugins/util/exrc_manager.lua`). They run at two points:
1. **Early** (before plugins) -- `source_local_config()` sources the file
2. **Late** (after all setup) -- `setup()` calls `_G.EXRC_M.setup()` if defined

Project configs expose state via `_G.EXRC_M` table. Common uses:
- Override lint config: `_G.EXRC_M = { lint = { "biome" } }`
- Add autocommands: `_G.EXRC_M = { autocmds = { ... } }`
- Custom setup logic: `_G.EXRC_M = { setup = function() ... end }`

## Common Tasks

### Adding Autocommands

Add to `lua/user/autocommands.lua`:
```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})
```

### Adding Vim Options

Edit `lua/user/options.lua` -- options are defined as a table iterated with `vim.opt[k] = v`.

### Creating Utility Functions

Add to or create files in `lua/user/utils/`:
```lua
-- lua/user/utils/my_utils.lua
local M = {}

M.my_function = function(args)
  -- implementation
end

return M

-- Usage: require("user.utils.my_utils").my_function(args)
```

The main `lua/user/utils/init.lua` provides `extend_lists()` and other shared helpers.

### Adding Snacks Pickers

Create a file in `lua/user/snacks/`, then wire it into the appropriate whichkey file:
```lua
-- lua/user/snacks/my_picker.lua
local Snacks = require("snacks")
local M = {}

function M.pick_things(opts)
  opts = opts or {}
  Snacks.picker({
    title = "My Picker",
    items = { ... },
    -- picker config
  })
end

return M
```

Then add a keymap in the relevant `whichkey/*.lua` file to call it.

## Code Style

- **Indentation**: Tabs (stylua configured with tabs)
- **Formatting**: stylua via EFM (auto-format on save)
- **Naming**: snake_case for files and functions
- **Error handling**: Always `pcall()` when requiring plugins
- **Imports**: `require("user.module")` for user code
- **Modern APIs**: `vim.keymap.set`, `vim.bo[bufnr]`, `vim.lsp.get_clients`, `vim.diagnostic.jump`, `vim.fs.root`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Plugins not loading | `:Lazy sync` then `:Lazy profile` |
| LSP not starting | `:checkhealth lsp`, check `lua/user/lsp/init.lua` for enabled servers |
| Mason packages missing | `:Mason`, check `lua/user/lsp/mason.lua` ensure_installed |
| Treesitter errors | `:TSUpdate` |
| Slow startup | `:Lazy profile` |
| Keybinding conflicts | `:verbose map <key>` or `:checkhealth which-key` |
| Format-on-save not working | Check `:LspInfo` for EFM attachment, read `lsp/efm.lua` |
| Icons missing | Install a Nerd Font |

### Health Check

```vim
:checkhealth
```

### Test Commands

```bash
# Test module loading
nvim --headless -c "lua require('user.plugins.category.name')" -c "qa"

# Test keymap discovery
nvim --headless -c "lua local p = require('user.whichkey.plugins'); print(vim.inspect(p.get_all_plugin_keymaps()))" -c "qa"
```

## References

These reference files contain additional detail. **Read them for specifics** rather than relying on summaries:

- [references/configuration.md](references/configuration.md) - Core configuration options
- [references/plugins.md](references/plugins.md) - Plugin details
- [references/plugin-deepdives.md](references/plugin-deepdives.md) - In-depth plugin guides
- [references/lsp.md](references/lsp.md) - LSP server reference
- [references/keybindings.md](references/keybindings.md) - Keybinding reference
- [references/debugging.md](references/debugging.md) - DAP debugging guide
- [references/performance.md](references/performance.md) - Optimization techniques
- [references/tools.md](references/tools.md) - CLI tools and workflows
- [references/troubleshooting.md](references/troubleshooting.md) - Common issues and solutions
- [references/migration-0.11.md](references/migration-0.11.md) - Neovim 0.11 migration guide

> **Note**: These reference files may be out of date. When in doubt, read the actual source files in `mods/dotfiles/nvim/` for ground truth.
