---
name: skill-neovim-implementation
description: Implement Neovim plugins and configurations with TDD. Invoke for lua-language implementation tasks.
allowed-tools: Read, Write, Edit, Bash(nvim:*, luacheck)
---

# Neovim Implementation Skill

Specialized implementation agent for Neovim configuration and Lua plugin development within this dotfiles repository.

## Trigger Conditions

This skill activates when:
- Task language is "lua"
- Implementation involves Neovim plugins, configurations, or utilities
- Plan exists with phases ready for execution

## Pre-Implementation Checklist

Before making changes, always:
1. Read `lua/user/plugin_registry.lua` for current plugin list and load order
2. Read `lua/user/lazy.lua` for plugin specs
3. Read `AGENTS.md` in the nvim directory for conventions
4. Check if the plugin/feature already exists in a module

## Testing Commands

```bash
# Test module loading
nvim --headless -c "lua require('user.plugins.category.name')" -c "qa"

# Test keymap discovery
nvim --headless -c "lua local p = require('user.whichkey.plugins'); print(vim.inspect(p.get_all_plugin_keymaps()))" -c "qa"

# Full health check
nvim --headless -c "checkhealth" -c "qa"

# Check for syntax errors
luacheck lua/ --codes
```

## Module Structure Patterns

### Directory Layout

```
mods/dotfiles/nvim/
├── lua/user/
│   ├── init.lua              # Entry point
│   ├── options.lua           # Editor options
│   ├── keymaps.lua           # Core keymaps
│   ├── lazy.lua              # lazy.nvim bootstrap + plugin specs
│   ├── plugin_registry.lua   # Module load order + keymap discovery
│   ├── autocommands.lua      # Autocommands
│   ├── plugins/              # Plugin configs by category
│   │   ├── ai/               # AI integrations (copilot, codecompanion, etc.)
│   │   ├── code/             # Code tools (blink.cmp, treesitter, etc.)
│   │   ├── database/         # Database tools (dadbod)
│   │   ├── debug/            # DAP debugging
│   │   ├── editing/          # Editing enhancements
│   │   ├── git/              # Git tools (gitsigns, diff, etc.)
│   │   ├── navigation/       # Navigation (oil, harpoon, etc.)
│   │   ├── ui/               # UI (colorscheme, lualine, bufferline, etc.)
│   │   └── util/             # Utility plugins
│   ├── lsp/                  # LSP orchestration (mason, attach, keymaps)
│   ├── whichkey/             # Which-key aggregation
│   ├── snacks/               # Snacks.nvim custom pickers
│   ├── dap/                  # DAP per-language configs
│   └── utils/                # Utility modules (file, git, project, collection)
├── lsp/                      # Native vim.lsp.config() server configs
└── after/ftplugin/           # Filetype-specific settings
```

### Standard Plugin Module Template

```lua
-- lua/user/plugins/category/plugin-name.lua
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
		shared = {},
	}
end

return M
```

### Adding New Plugins

1. **Install the plugin** in `lua/user/lazy.lua`
2. **Create a plugin module** in `lua/user/plugins/<category>/<name>.lua`
3. **Register in `lua/user/plugin_registry.lua`** -- add the module path to `M.modules` in the appropriate position (order matters for dependencies)
4. **Implement the module** with `setup()` and optionally `get_keymaps()`

### Adding New LSP Servers

1. **Create config** in top-level `lsp/<servername>.lua` returning a table for `vim.lsp.config()`
2. **Add to `vim.lsp.enable()`** in `lua/user/lsp/init.lua`
3. **Add to mason `ensure_installed`** in `lua/user/lsp/mason.lua`

## Error Handling Patterns

### Using pcall for Safe Plugin Requires

```lua
local ok, plugin = pcall(require, "plugin-name")
if not ok then
	vim.notify("plugin-name not found")
	return
end
```

**IMPORTANT**: Always check `ok`, not the module value. When `pcall` fails, `ok` is `false` and the second return value is the error message string (truthy), so checking `if not module` will not catch failures.

### User Notifications

```lua
vim.notify("Operation completed", vim.log.levels.INFO)
vim.notify("Missing optional dependency", vim.log.levels.WARN)
vim.notify("Critical error: " .. err, vim.log.levels.ERROR)
```

## Quality Standards

- **Indentation**: Tabs (configured via stylua)
- **Formatting**: stylua via EFM LSP (auto-format on save)
- **Line length**: ~100 characters
- **Naming**: snake_case for files and functions
- **Comments**: LuaDoc style for public APIs
- **Error handling**: pcall for all external plugin dependencies
- **Modern APIs only**: See list below

### Modern API Requirements

Always use these over deprecated alternatives:
- `vim.keymap.set` (not `vim.api.nvim_set_keymap`)
- `vim.bo[bufnr]` / `vim.wo[winnr]` (not `nvim_buf_get_option` / `nvim_buf_set_option`)
- `vim.json.decode` (not `vim.fn.json_decode`)
- `vim.diagnostic.jump({ count = N })` (not `goto_next` / `goto_prev`)
- `vim.lsp.get_clients()` (not `get_client_by_id` or `get_active_clients`)
- `vim.api.nvim_create_user_command` (not `vim.cmd("command! ...")`)
- `vim.api.nvim_create_autocmd` (not VimScript `augroup`/`autocmd` blocks)

## Key Codebase Locations

- **Entry point**: `mods/dotfiles/nvim/lua/user/init.lua`
- **Plugin registry**: `mods/dotfiles/nvim/lua/user/plugin_registry.lua`
- **Plugin specs**: `mods/dotfiles/nvim/lua/user/lazy.lua`
- **Plugin configs**: `mods/dotfiles/nvim/lua/user/plugins/`
- **LSP configs**: `mods/dotfiles/nvim/lsp/` (native) + `mods/dotfiles/nvim/lua/user/lsp/` (orchestration)
- **Which-key**: `mods/dotfiles/nvim/lua/user/whichkey/`
- **Snacks pickers**: `mods/dotfiles/nvim/lua/user/snacks/`
- **Utilities**: `mods/dotfiles/nvim/lua/user/utils/`
- **Guidelines**: `mods/dotfiles/nvim/AGENTS.md`
