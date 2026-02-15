---
name: skill-neovim-research
description: Research Neovim APIs, plugin patterns, and Lua development. Invoke for lua-language research tasks.
allowed-tools: Read, Glob, Grep, WebSearch, WebFetch
---

# Neovim Research Skill

Specialized research agent for Neovim configuration and Lua plugin development tasks within this dotfiles repository.

## Trigger Conditions

This skill activates when:
- Task language is "lua"
- Research involves Neovim APIs, plugins, or configuration
- Codebase exploration for Lua patterns is needed

## Research Strategies

### 1. Local Codebase First

Always check existing code first:
```
1. Grep for relevant patterns in lua/user/
2. Glob for similar modules in lua/user/plugins/
3. Read existing implementations
4. Understand existing patterns before proposing new ones
```

### 2. Neovim API Research

For Neovim-specific patterns:
```
1. WebSearch "neovim lua {concept}"
2. WebFetch neovim.io documentation
3. Check existing patterns in lua/user/
4. Reference the nvim/AGENTS.md for standards
```

### 3. Plugin Research

For plugin-specific patterns:
```
1. Read plugin documentation via WebFetch
2. Check existing plugin configs in lua/user/plugins/
3. Search GitHub repos for patterns
4. Check plugin_registry.lua for current plugin list
```

## Research Areas

### Neovim API Patterns
- `vim.api.*` (buffer, window, command APIs)
- `vim.fn.*` (Vimscript function bridge)
- `vim.opt.*` (option setting)
- `vim.keymap.set()` (keymapping)
- `vim.api.nvim_create_autocmd()` (autocommands)
- `vim.lsp.*` (language server protocol)
- `vim.diagnostic.*` (diagnostics)

### Plugin APIs
- lazy.nvim (plugin management, lazy loading)
- snacks.nvim (pickers, dashboard, notifier -- replaces telescope)
- nvim-treesitter (syntax parsing)
- which-key.nvim v3 (keybinding documentation)
- codecompanion.nvim (AI chat)
- blink.cmp (completion)

### Lua Patterns
- Module structure (`local M = {}`)
- Error handling (`pcall`)
- Table manipulation
- String patterns
- Metatable usage

### Configuration Patterns
- Options organization
- Keymap centralization via which-key aggregation
- Autocommand grouping
- Plugin lazy loading strategies
- Plugin registry pattern for module loading and keymap discovery

## Execution Flow

```
1. Receive task context (description, focus)
2. Extract key concepts (API type, plugin, pattern)
3. Search local codebase for related patterns
4. Search web for Neovim/plugin documentation
5. Analyze implementation approaches
6. Synthesize findings
7. Return results
```

## Key Resources

### Official Documentation
- https://neovim.io/doc/user/lua.html - Neovim Lua guide
- https://neovim.io/doc/user/api.html - Neovim API reference
- https://neovim.io/doc/user/lsp.html - LSP integration

### Plugin Documentation
- https://lazy.folke.io/ - lazy.nvim plugin manager
- https://github.com/folke/snacks.nvim - Snacks.nvim (pickers, UI)
- https://github.com/nvim-treesitter/nvim-treesitter - Syntax parsing
- https://luals.github.io/ - Lua language server

### Community Resources
- https://github.com/nanotee/nvim-lua-guide - Comprehensive Lua guide
- https://github.com/rockerBOO/awesome-neovim - Plugin collection

## Key Codebase Locations

- **Entry point**: `mods/dotfiles/nvim/lua/user/init.lua`
- **Options**: `mods/dotfiles/nvim/lua/user/options.lua`
- **Keymaps**: `mods/dotfiles/nvim/lua/user/keymaps.lua`
- **Plugin specs**: `mods/dotfiles/nvim/lua/user/lazy.lua`
- **Plugin registry**: `mods/dotfiles/nvim/lua/user/plugin_registry.lua`
- **Plugin configs**: `mods/dotfiles/nvim/lua/user/plugins/` (categories: ai, code, database, debug, editing, git, navigation, ui, util)
- **LSP server configs**: `mods/dotfiles/nvim/lsp/` (native vim.lsp.config)
- **LSP orchestration**: `mods/dotfiles/nvim/lua/user/lsp/` (mason, attach, keymaps)
- **Which-key**: `mods/dotfiles/nvim/lua/user/whichkey/`
- **Snacks pickers**: `mods/dotfiles/nvim/lua/user/snacks/`
- **Utilities**: `mods/dotfiles/nvim/lua/user/utils/`
- **DAP configs**: `mods/dotfiles/nvim/lua/user/dap/`
- **Guidelines**: `mods/dotfiles/nvim/AGENTS.md`

## Modern API Requirements

Always prefer these modern APIs over deprecated alternatives:
- `vim.keymap.set` (not `nvim_set_keymap`)
- `vim.bo[bufnr]` / `vim.wo[winnr]` (not `nvim_buf_get_option`)
- `vim.json.decode` (not `vim.fn.json_decode`)
- `vim.diagnostic.jump` (not `goto_next` / `goto_prev`)
- `vim.lsp.get_clients` (not `get_client_by_id` or `get_active_clients`)

## Quick Exploration Commands

```lua
-- Check available API functions
:lua print(vim.inspect(vim.api))

-- Check option values
:lua print(vim.inspect(vim.opt.tabstop:get()))

-- Check loaded modules
:lua print(vim.inspect(package.loaded))

-- Find keymap conflicts
:verbose map <key>
```
