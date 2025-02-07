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

