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
- **Language**: Lua for configuration (legacy VimScript in init.vim is minimal)
- **Indentation**: 2 spaces for Lua (set in options.lua); use tabs consistently
- **Formatting**: Use stylua for Lua formatting (configured via efm LSP)
- **File organization**: Modular structure - `lua/user/` contains feature modules, `lsp/` for language server configs
- **Imports**: Use `require("user.module")` for user configs; pcall for optional dependencies
- **Error handling**: Always use `pcall()` when requiring plugins that might not be installed
- **Naming**: Use snake_case for Lua files/functions (e.g., `find_files.lua`, `lsp_keymaps()`)

## Architecture Patterns
- **Plugin manager**: lazy.nvim - all plugins defined in `lua/user/lazy.lua`
- **LSP setup**: Separate config files in `lsp/` directory for each language server (vtsls.lua, gopls.lua, etc.)
- **Modular structure**: Each feature has its own file (gitsigns.lua, treesitter.lua, etc.)
- **Initialization order**: init.vim → user/init.lua → feature modules loaded in sequence
- **Project-specific config**: `.nvim.lua` files in project roots via exrc_manager (see readme.md template)
- **Keybindings**: Organized in whichkey/ directory by category (git.lua, find.lua, lsp.lua, etc.)
- **Leader key**: Space (`<leader>`) and semicolon (`<localleader>`)
- **LSP detection**: Conditional enabling based on project markers (e.g., deno.json → denols, else vtsls)

## Key Concepts
- **Snacks.nvim**: Custom pickers/finders in `snacks/` directory replacing telescope
- **Which-key**: All keybindings documented and organized by prefix in `whichkey/whichkey.lua`
- **EFM LSP**: Handles formatters/linters via efmls-configs (prettier, eslint, ruff, etc.)
- **DAP**: Debugger configs per language in `dap/` directory (python.lua, go.lua, typescript.lua)
- **Utility modules**: Helper functions in `_file_utils.lua`, `_git_utils.lua`, `_project_utils.lua`, `_collection_utils.lua`
## Neovim Plugin Development

### Adding New Plugins
When adding new neovim plugins, follow this workflow:

1. **Install the plugin** in `mods/dotfiles/nvim/lua/user/lazy.lua`
2. **Create a plugin module** in `mods/dotfiles/nvim/lua/user/plugins/<category>/<name>.lua`
   - Categories: `ai`, `code`, `database`, `debug`, `editing`, `git`, `navigation`, `ui`, `util`
3. **Register in plugin_registry.lua** - Add the module path to the `M.modules` array in the appropriate position
   - **IMPORTANT**: Order matters! Some plugins must load early (e.g., `ui.notify`, `ui.colorscheme`)
   - Place new plugins in a logical position based on their dependencies
4. **Implement the module**:
   ```lua
   local M = {}
   
   function M.setup()
     -- Plugin configuration
   end
   
   function M.get_keymaps()  -- Optional, for automatic keymap registration
     return {
       normal = {
         { "<leader>xx", "<cmd>Command<cr>", desc = "Description" },
       },
     }
   end
   
   return M
   ```

### Plugin Registry System
- **Registry location**: `mods/dotfiles/nvim/lua/user/plugin_registry.lua`
- **Purpose**: Single source of truth for all plugin modules
- **Used by**: 
  - `init.lua` - Calls `setup()` on each module in order
  - `whichkey/plugins.lua` - Discovers and loads keymaps from modules
- **Maintains load order**: Critical plugins (colorscheme, notify) load first
- **Keymap detection**: Automatic - modules with `get_keymaps()` are automatically discovered
- **No manual flags**: System dynamically detects which modules export keymaps at runtime


