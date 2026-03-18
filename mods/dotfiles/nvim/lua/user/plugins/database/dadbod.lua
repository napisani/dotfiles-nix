-- dadbod.lua
-- Database tooling configuration using vim-dadbod + dadbod-grip

local M = {}

local function close_grip_windows()
	local closed = 0
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			local name = vim.api.nvim_buf_get_name(buf)
			local ft = vim.bo[buf].filetype or ""
			local is_grip = name:match("^grip://") or ft:match("^grip")
			if is_grip then
				pcall(vim.api.nvim_win_close, win, false)
				closed = closed + 1
			end
		end
	end

	if closed == 0 then
		vim.notify("No Grip windows are open", vim.log.levels.INFO)
	end
end

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

	local ok_grip, grip = pcall(require, "dadbod-grip")
	if not ok_grip then
		vim.notify("dadbod-grip not found", vim.log.levels.ERROR)
		return
	end

	grip.setup({
		picker = "snacks",
		keymaps = {
			qpad_execute = "<leader>De",
		},
	})
end

--- Get keymaps for dadbod-grip
-- @return table with shared, normal, and visual mode keymaps
function M.get_keymaps()
	return {
		shared = {},
		normal = {
			{ "<leader>D", group = "Database" },
			{ "<leader>Do", "<Cmd>GripConnect<CR>", desc = "(o)pen" },
			{
				"<leader>Dq",
				function()
					close_grip_windows()
				end,
				desc = "(q)uit",
			},
			{ "<leader>Ds", "<Cmd>GripSchema<CR>", desc = "(s)chema" },
			{ "<leader>Dt", "<Cmd>GripTables<CR>", desc = "(t)ables" },
			{ "<leader>Dg", "<Cmd>Grip<CR>", desc = "(g)rid" },
			{ "<leader>Dh", "<Cmd>GripHistory<CR>", desc = "(h)istory" },
			{ "<leader>De", "<Cmd>GripQuery<CR>", desc = "query (e)ditor" },
			{ "<leader>Dd", "<Cmd>GripStart<CR>", desc = "(d)emo" },
		},
		visual = {},
	}
end

return M
