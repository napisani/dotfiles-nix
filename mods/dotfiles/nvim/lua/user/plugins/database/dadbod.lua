-- dadbod.lua
-- Database UI plugin configuration for vim-dadbod

local M = {}

--- Setup function for vim-dadbod-ui
-- Configures database connections from project config and sets UI options
function M.setup()
	local utils = require("user.utils")

	--[=====[ 
	// dbs.json
	{
	  "connections": {
	    "name": "URL"
	  }
	}
	--]=====]

	local function get_project_db_urls()
		local dbs_file = utils.get_root_dir() .. "/dbs.json"
		local json_file = utils.read_json_file(dbs_file)
		if json_file == nil then
			return {}
		end
		local conns = {}
		if json_file["connections"] ~= nil then
			conns = json_file["connections"]
		end
		return conns
	end

	local project = utils.get_project_config()
	if project.db_ui_save_location ~= nil then
		vim.g.db_ui_save_location = project.db_ui_save_location
	end
	if project.db_ui_tmp_query_location ~= nil then
		vim.g.db_ui_tmp_query_location = project.db_ui_tmp_query_location
	end

	vim.g.dbs = get_project_db_urls()
	vim.g.db_ui_use_nerd_fonts = 1
end

--- Get keymaps for vim-dadbod-ui
-- @return table with shared, normal, and visual mode keymaps
function M.get_keymaps()
	return {
		shared = {},
		normal = {
			{ "<leader>Do", "<Cmd>DBUI<CR>", desc = "(o)pen" },
			{ "<leader>Dq", "<Cmd>DBUIClose<CR>", desc = "(q)uit" },
			{ "<leader>DW", "<plug>(DBUI_SaveQuery)", desc = "Save Query" },
			{ "<leader>Dr", "DBUIRenameBuffer", desc = "Rename Buffer" },
		},
		visual = {},
	}
end

return M
