# Agent Guidelines for Nix/Home-Manager Dotfiles

This repository is a **Nix flake** for configuring and managing multiple systems (macOS via nix-darwin and NixOS). It contains:
1. **Root project**: Nix flake for system/package configuration and dotfile management
2. **Sub-project: Karabiner** - Keyboard configuration at `./mods/dotfiles/karabiner`
3. **Sub-project: Neovim** - Editor configuration at `./mods/dotfiles/nvim`

**Important**: Each sub-project has its own conventions, build processes, and testing procedures detailed below.

---

## Root Project: Nix/Home-Manager Configuration

### Build & Test Commands
- **Validate configuration**: `nix build .#darwinConfigurations.<hostname>.system --dry-run` (macOS) or `nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --dry-run` (Linux)
- **Format Nix files**: `nix fmt <file>.nix`
- **Lint Nix files**: `statix check .`
- **Check flake metadata**: `nix flake metadata` (verify flake structure and inputs)
- **IMPORTANT**: Do NOT run actual build/switch commands (`darwin-rebuild switch`, `nixos-rebuild switch`) - only validate changes

### Code Style & Conventions
- **Language**: Nix expression language for system/package configuration
- **Formatting**: Use `nixfmt-classic` for consistent formatting; 2-space indentation
- **File organization**: Modular structure - `mods/` for modules, `homes/` for user configs, `systems/` for system configs
- **Imports**: Use relative paths (e.g., `../mods/neovim.nix`); organize by category (language, tool, system)
- **Package preferences**: Prefer `pkgs-unstable` for most packages to get latest versions
- **Naming**: Use kebab-case for files (e.g., `base-packages.nix`), descriptive module names
- **Configuration**: Symlink dotfiles from `mods/dotfiles/` using `mkOutOfStoreSymlink` for editability
- **Comments**: Add inline comments for non-obvious configurations or workarounds

### Architecture Patterns
- **Flake-based**: All configurations use flake.nix with inputs/outputs structure
- **Platform separation**: Darwin (macOS) vs NixOS (Linux) configs are split; share common modules
- **Home-Manager integration**: User environment managed via home-manager, not imperative installs
- **Language modules**: Language tooling organized in `mods/languages/`, imported via `all.nix`

---

## Sub-Project: Karabiner Keyboard Configuration

**Location**: `./mods/dotfiles/karabiner`

### Build & Test Commands
```bash
# Navigate to karabiner directory
cd mods/dotfiles/karabiner

# Generate karabiner.json (writes to ../karabiner.json - one level up!)
deno task build

# Reload Karabiner to apply changes
karabiner-reload.sh

# If reload doesn't work, fully restart
osascript -e 'quit app "Karabiner-Elements"' && sleep 1 && open -a 'Karabiner-Elements'
```

### Code Style & Conventions
- **Language**: TypeScript with Deno runtime
- **Formatting**: Use `deno fmt` for formatting
- **File organization**: Modular - each feature in separate file in `src/` directory
- **Naming**: Use kebab-case for files (e.g., `cap-modifier.ts`, `system-leader.ts`)
- **Exports**: Export rule arrays (e.g., `export const layerRules = [...]`)
- **Imports**: Import karabiner.ts library and local modules; always include `../polyfill.ts` in index.ts

### Architecture Patterns
- **Generated config**: TypeScript sources generate JSON config file
- **Output path**: Builds to `../karabiner.json` (one directory up from karabiner/)
- **Symlink managed by Nix**: Generated JSON is symlinked to `~/.config/karabiner/karabiner.json` via home-manager
- **Edit-generate-reload workflow**: Modify TS → run build → reload Karabiner (no Nix rebuild needed)
- **Module composition**: Each feature file exports rules, imported and composed in `src/index.ts`

### Key Concepts
- **Layer-based mappings**: Simultaneous key layers (simlayer) in `layers.ts` - hold key to activate layer
- **Modifier swapping**: Remap modifier keys in `modifierSwap.ts`
- **Caps Lock modifier**: Custom Caps Lock behavior in `cap-modifier.ts`
- **Hyper key**: Define Hyper key (Cmd+Opt+Ctrl+Shift) in `hyper.ts`
- **Leader sequences**: Vim-like leader key system in `leader-utils.ts` and `system-leader.ts`
- **Window management**: Window/tab navigation in `window-layer.ts`

### Adding New Rules
1. Create or edit a file in `src/` (e.g., `src/my-feature.ts`)
2. Export rules array: `export const myFeatureRules = [rule(...).manipulators([...])]`
3. Import in `src/index.ts`: `import { myFeatureRules } from "./my-feature.ts";`
4. Add to `writeToProfile()` array: `...myFeatureRules,`
5. Run `deno task build && karabiner-reload.sh`

### Important Notes
- **Output location**: Generated file is `~/.config/home-manager/mods/dotfiles/karabiner.json` (NOT inside karabiner/ dir)
- **Symlink**: DO NOT manually edit or touch `~/.config/karabiner/karabiner.json` - breaks symlink
- **Version control**: Commit both TypeScript sources AND generated JSON
- **Broken symlink**: Run `darwin-rebuild switch --flake .#<hostname>` to restore

---

## Sub-Project: Neovim Configuration

**Location**: `./mods/dotfiles/nvim`

### Build & Test Commands
```bash
# Test plugin module loading
nvim --headless -c "lua require('user.plugins.category.name')" -c "qa"

# Test keymap discovery
nvim --headless -c "lua local p = require('user.whichkey.plugins'); print(vim.inspect(p.get_all_plugin_keymaps()))" -c "qa"

# Test full config
nvim --headless -c "checkhealth" -c "qa"
```

### Code Style & Conventions
- **Language**: Lua for configuration (minimal legacy VimScript in init.vim)
- **Formatting**: Use stylua for Lua formatting (via efm LSP)
- **File organization**: Modular - `lua/user/` for feature modules, `lsp/` for language servers, `lua/user/plugins/` for plugin configs
- **Naming**: Use snake_case for Lua files/functions (e.g., `find_files.lua`, `lsp_keymaps()`)
- **Imports**: Use `require("user.module")` for user configs
- **Error handling**: Always use `pcall()` when requiring plugins that might not be installed

### Architecture Patterns
- **Plugin manager**: lazy.nvim - plugins defined in `lua/user/lazy.lua`
- **Plugin registry**: Centralized module registry in `lua/user/plugin_registry.lua`
- **LSP setup**: Separate config files in `lsp/` directory for each language server
- **Modular structure**: Each feature has its own file with `setup()` function
- **Initialization order**: init.vim → user/init.lua → plugin registry loads modules in sequence
- **Keybindings**: Organized in `whichkey/` directory by category

### Key Concepts
- **Plugin Registry**: Single source of truth (`plugin_registry.lua`) - maintains load order, auto-discovers keymaps
- **Snacks.nvim**: Custom pickers/finders in `snacks/` directory
- **Which-key**: All keybindings documented and organized by prefix
- **EFM LSP**: Handles formatters/linters (prettier, eslint, ruff, etc.)
- **DAP**: Debugger configs per language in `dap/` directory
- **Utility modules**: Helper functions in `utils/` (file_utils, git_utils, project_utils, collection_utils)

### Adding New Plugins
1. **Install the plugin** in `lua/user/lazy.lua`
2. **Create a plugin module** in `lua/user/plugins/<category>/<name>.lua`
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
       visual = {
         -- Visual mode keymaps
       },
       shared = {
         -- Keymaps for both normal and visual mode
       },
     }
   end
   
   return M
   ```

### Plugin Registry System
- **Registry location**: `lua/user/plugin_registry.lua`
- **Purpose**: Single source of truth for all plugin modules
- **Used by**: 
  - `init.lua` - Calls `setup()` on each module in order
  - `whichkey/plugins.lua` - Discovers and loads keymaps from modules
- **Maintains load order**: Critical plugins (colorscheme, notify) load first
- **Keymap detection**: Automatic - modules with `get_keymaps()` are automatically discovered
- **No manual flags**: System dynamically detects which modules export keymaps at runtime

---

## General Guidelines

### When Working on This Repository

1. **Identify the scope**: Determine if you're working on Nix configs, Karabiner, or Neovim
2. **Follow sub-project conventions**: Each sub-project has different languages, tools, and patterns
3. **Test appropriately**: Use the correct build/test commands for each sub-project
4. **Rebuild when needed**: 
   - Nix changes → rebuild with darwin-rebuild/nixos-rebuild
   - Karabiner changes → regenerate JSON and reload
   - Neovim changes → no rebuild needed (live reloadable)
