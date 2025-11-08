# Agent Guidelines for Neovim Configuration

## Testing & Validation
- **No automated tests**: This is a configuration repository; validation happens by launching nvim
- **Test config**: Open `nvim` and check for errors; run `:checkhealth` to verify plugin/LSP status
- **Plugin management**: Use `:Lazy` to manage plugins; `:Lazy sync` to install/update
- **LSP status**: Check with `:LspInfo`, `:Mason` for language server management
- **Tree-sitter**: Update parsers with `:TSUpdate`

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
