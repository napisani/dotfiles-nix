# Agent Guidelines for Nix/Home-Manager Dotfiles

## Build & Test Commands
- **Build**: `nixswitchup` 
- **Format Nix files**: `nix fmt <file>.nix`
- **Lint Nix files**: `statix check .`
- **No test framework**: This is a configuration repository; validation happens via successful builds

## Code Style & Conventions
- **Language**: Nix expression language for system/package configuration
- **Formatting**: Use `nixfmt-classic` for consistent formatting; 2-space indentation
- **File organization**: Modular structure - `mods/` for modules, `homes/` for user configs, `systems/` for system configs
- **Imports**: Use relative paths (e.g., `../mods/neovim.nix`); organize by category (language, tool, system)
- **Package preferences**: Prefer `pkgs-unstable` for most packages to get latest versions
- **Naming**: Use kebab-case for files (e.g., `base-packages.nix`), descriptive module names
- **Configuration**: Symlink dotfiles from `mods/dotfiles/` using `mkOutOfStoreSymlink` for editability
- **Comments**: Add inline comments for non-obvious configurations or workarounds (see git.nix examples)

## Architecture Patterns
- **Flake-based**: All configurations use flake.nix with inputs/outputs structure
- **Platform separation**: Darwin (macOS) vs NixOS (Linux) configs are split; share common modules
- **Home-Manager integration**: User environment managed via home-manager, not imperative installs
- **Language modules**: Language tooling organized in `mods/languages/`, imported via `all.nix`

## Neovim Plugin Development

### Adding New Plugins
When adding new neovim plugins, follow this workflow:

1. **Install the plugin** in `mods/dotfiles/nvim/lua/user/core/lazy.lua`
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

### Testing Neovim Changes
```bash
# Test plugin module loading
nvim --headless -c "lua require('user.plugins.category.name')" -c "qa"

# Test keymap discovery
nvim --headless -c "lua local p = require('user.whichkey.plugins'); print(vim.inspect(p.get_all_plugin_keymaps()))" -c "qa"

# Test full config
nvim --headless -c "checkhealth" -c "qa"
```




