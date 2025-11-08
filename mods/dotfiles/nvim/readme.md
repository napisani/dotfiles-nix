# Neovim Configuration

## Plugin Architecture

### Modular Plugin System
Plugins are organized in a modular structure under `lua/user/plugins/` with automatic keymap discovery:

**Directory Structure:**
```
lua/user/plugins/
├── ai/           # AI and code completion plugins
├── code/         # Code editing and treesitter
├── database/     # Database plugins (dadbod, etc.)
├── debug/        # Debugging plugins (nvim-dap)
├── editing/      # Editing enhancements (autopairs, comments)
├── git/          # Git integration (gitsigns, neogit, diffview)
├── navigation/   # Navigation plugins (hop, oil, tmux-nav)
├── ui/           # UI plugins (lualine, bufferline, etc.)
└── util/         # Utility plugins
```

**Plugin Module Pattern:**
Each plugin module can export:
- `setup()` - Called during initialization to configure the plugin
- `get_keymaps()` - Returns keymaps that are automatically registered with which-key

**Adding a New Plugin:**
1. Install the plugin in `lua/user/core/lazy.lua`
2. Create a module in `lua/user/plugins/<category>/<name>.lua`
3. Register the module path in `lua/user/plugin_registry.lua` (maintains load order)
4. Implement `setup()` and optionally `get_keymaps()`

**Plugin Registry:**
- **Location**: `lua/user/plugin_registry.lua`
- **Single source of truth** for all plugin modules
- **Maintains load order** - critical plugins (colorscheme, notify) load first
- **Used by**: 
  - `init.lua` - Calls `setup()` on modules
  - `whichkey/plugins.lua` - Discovers keymaps automatically

**Keymap Format:**
```lua
function M.get_keymaps()
  return {
    normal = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open diffview" },
    },
    visual = {
      -- visual mode keymaps
    },
    shared = {
      -- keymaps for both normal and visual modes
    },
  }
end
```

Keymaps are automatically discovered and registered - no manual configuration needed!

## Useful Commands

:LspInfo  -- show info about currently connected LSP server 
:LspInstallInfo -- show language servers that are installed / install new ones
:messages - show all vim.notify("test")
:NullLsInfo - show info about extra diagnostics and formatters attached to the open file



:Gvsplitdiff! origin/main   - compare in vsplit buffer (Side by side)
:G blame - show blame annoations on the left gutter


:DiffViewOpen %    - shows diff view for current file
:DiffViewOpen     - shows diff view for current workspace
:DiffViewOpen  main..HEAD   - shows diff to main 
:DiffViewClose - closes diff view



-- in vimdiff view
zo - open hidden section
zc - collapse expanded section


-- rust
:RustDebuggables to select a target for debugging

-- update tree sitter
:TSUpdate


## Create a project nvimrc.lua
```lua
-- this is a template for a project nvimrc.lua file
local project_config = {
	branches = {
		main = "develop",
		prod = "main",
	},
	debug = {
		launch_file = ".nvimlaunch.json",
	},
	autocmds = {
		{
			event = "BufWritePre",
			pattern = "*.go",
			command = "!procmux signal-start --name run-day",
		},
	},
	commands = {
		{
			command = "procmux signal-start --name run-day",
			description = "procmux signal start run day",
		},
	},
	lint = {
		"eslint",
		"prettier",
	},

	db_ui_save_location = "./sql_scripts_tmp",
	db_ui_tmp_query_location = "/sql_scripts/",
}

_G.EXRC_M = {
	project_config = project_config,

	setup = function() end,
}
```


## Configure project database connections
create a file called `dbs.json`
```json
{
  "connections": {
    "name": "URL"
    "pg_connection" : "postgres://user:password@localhost:5432/mydatabase",
    "mysql_connection" : "mysql://user:password@localhost:3306/mydatabase",
    "sqlite_connection" : "sqlite:///path/to/mydatabase.db",
  }
}
```


## Include project specific search files

To force certain files to be included per project
use a `.ignore` file at the root of the project and use
```bash
# syntax like
!*.env.* # this will force .env files to be included in all searches
```
