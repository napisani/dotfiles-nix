# Agent Guidelines for Neovim Configuration

## Testing & Validation
```bash
# Test plugin module loading
nvim --headless -c "lua require('user.plugins.category.name')" -c "qa"

# Test keymap discovery
nvim --headless -c "lua local p = require('user.whichkey.plugins'); print(vim.inspect(p.get_all_plugin_keymaps()))" -c "qa"

# Test full config
nvim --headless -c "checkhealth" -c "qa"
```

## Code Style & Conventions
- **Language**: Lua for configuration (minimal legacy VimScript in init.vim bootstrap)
- **Indentation**: Tabs for Lua (stylua configured with tabs)
- **Formatting**: stylua via efm LSP (auto-format on save)
- **File organization**: `lua/user/` for feature modules, top-level `lsp/` for server configs, `lua/user/plugins/` for plugin configs
- **Imports**: Use `require("user.module")` for user configs; `pcall` for optional dependencies
- **Error handling**: Always use `pcall()` when requiring plugins that might not be installed
- **Naming**: snake_case for Lua files and functions (e.g., `find_files.lua`, `lsp_keymaps()`)
- **Modern Neovim APIs**: Prefer these over deprecated alternatives:
  - `vim.keymap.set` (not `nvim_set_keymap`)
  - `vim.bo[bufnr]` / `vim.wo[winnr]` (not `nvim_buf_get_option`)
  - `vim.json.decode` (not `vim.fn.json_decode`)
  - `vim.diagnostic.jump` (not `goto_next` / `goto_prev`)
  - `vim.lsp.get_clients` (not `get_client_by_id` or `get_active_clients`)
  - `vim.fs.root` (not manual directory traversal)

## Architecture Patterns

### Plugin Manager
lazy.nvim -- all plugins defined in `lua/user/lazy.lua`.

### Plugin Registry
`lua/user/plugin_registry.lua` -- single source of truth for all plugin modules. Maintains load order and auto-discovers keymaps from modules that export `get_keymaps()`.

### Dual LSP Architecture
- **Top-level `lsp/` directory**: Native `vim.lsp.config()` server configs (auto-loaded by Neovim 0.11+). Each file returns a table with server settings, root_markers, filetypes, etc.
- **`lua/user/lsp/`**: Orchestration layer -- mason setup (`mason.lua`), LspAttach keymaps (`attach.lua` + `keymaps.lua`), code actions (`actions.lua`).
- **`lsp/init.lua`** (at `lua/user/lsp/init.lua`): Calls `vim.lsp.enable()` for all servers.

### Initialization Order
```
init.vim
  -> user/init.lua
    -> exrc_manager.source_local_config()  (.nvim.lua project config)
    -> user/options
    -> user/keymaps
    -> user/lazy (lazy.nvim bootstrap + plugin specs)
    -> user/lsp (mason, attach, vim.lsp.enable)
    -> plugin_registry loop (setup() on each module)
    -> whichkey/whichkey (aggregates all keymaps)
    -> user/autocommands
    -> exrc_manager.setup() (finalize project config)
```

### Keybindings
Organized in `lua/user/whichkey/` directory by category. Aggregated in `whichkey.lua` which combines mappings from:
- `find_snacks.lua`, `search_snacks.lua`, `replace.lua`, `repl.lua`, `scopes.lua`, `lsp.lua`, `global.lua`
- Plugin keymaps auto-discovered from registry modules via `whichkey/plugins.lua`

**Leader keys**: Space (`<leader>`), semicolon (`<localleader>`)

### Project-Specific Config
`.nvim.lua` files in project roots via `exrc_manager`. Loaded early (before plugins) and finalized late (after all setup). Expose config through `_G.EXRC_M` table. Can override lint config, add autocmds, etc.

### Picker Framework
Snacks.nvim (NOT telescope) -- custom pickers in `lua/user/snacks/` directory. Handles file finding, grep, git search, AI actions, commands, and more.

### LSP Detection
- `deno.json` or `deno.jsonc` present -> `denols` enabled, `vtsls` disabled
- Otherwise -> `vtsls` enabled, `denols` disabled
- These are mutually exclusive to avoid conflicts

### EFM Format on Save
Auto-formats via `BufWritePost` autocmd using efm LSP. Auto-detects formatters per project:
- `deno.json` present -> `deno_fmt`
- `biome.json` / `rome.json` present -> `biome`
- Otherwise -> `eslint_d` + `eslint_d` format
- Can be overridden via `.nvim.lua` project config (`lint` table)

## Key Concepts
- **Plugin Registry**: Single source of truth for module loading and keymap discovery (`lua/user/plugin_registry.lua`)
- **Snacks.nvim**: Pickers, dashboard, notifier, buffer delete, command launcher -- replaces telescope
- **Which-key**: v3 API, keymaps from multiple sources aggregated in `whichkey.lua`
- **EFM LSP**: Formatters/linters per language (see `lsp/efm.lua` for full language map)
- **DAP**: Per-language debug configs in `lua/user/dap/` (python, go, typescript)
- **Utility modules**: `lua/user/utils/` (file_utils, git_utils, project_utils, collection_utils)
- **AI plugins**: copilot, codecompanion, opencode, wiremux, code_explain -- each has a module in `plugins/ai/`

## Adding New Plugins

1. **Install the plugin** in `lua/user/lazy.lua`
2. **Create a plugin module** in `lua/user/plugins/<category>/<name>.lua`
   - Categories: `ai`, `code`, `database`, `debug`, `editing`, `git`, `navigation`, `ui`, `util`
3. **Register in `lua/user/plugin_registry.lua`** -- add the module path to `M.modules` in the appropriate position
   - **IMPORTANT**: Order matters! Some plugins must load early (e.g., `ui.notify`, `ui.colorscheme`)
   - Place new plugins in a logical position based on their dependencies
4. **Implement the module**:
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

   function M.get_keymaps() -- Optional, for automatic keymap registration
     return {
       normal = {
         { "<leader>xx", "<cmd>Command<cr>", desc = "Description" },
       },
       visual = {
         { "<leader>xx", "<cmd>Command<cr>", desc = "Description" },
       },
       shared = {
         { "<leader>x", group = "Group Name" },
         { "<leader>xy", "<cmd>Command<cr>", desc = "Description" },
       },
     }
   end

   return M
   ```

## Plugin Registry System
- **Location**: `lua/user/plugin_registry.lua`
- **Used by**:
  - `init.lua` -- calls `setup()` on each module in order
  - `whichkey/plugins.lua` -- discovers and loads keymaps from modules
- **Load order matters**: UI plugins first (colorscheme, notify), then features
- **Dynamic keymap detection**: Modules with `get_keymaps()` are automatically discovered at runtime -- no manual flags needed

## Adding New LSP Servers

1. **Create config file** in top-level `lsp/<servername>.lua` returning a table for `vim.lsp.config()`:
   ```lua
   return {
     root_markers = { "marker_file" },
     settings = {
       -- server-specific settings
     },
   }
   ```
2. **Add to `vim.lsp.enable()`** call in `lua/user/lsp/init.lua`
3. **Add to mason `ensure_installed`** in `lua/user/lsp/mason.lua`
4. **Optionally add per-server keymaps** in `lua/user/lsp/keymaps.lua` under `M.per_server`
