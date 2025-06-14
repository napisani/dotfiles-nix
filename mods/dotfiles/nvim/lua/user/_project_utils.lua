local file_utils = require("user._file_utils")
local M = {}

local default_config = {
	lint = {},
	branches = {
		main = "main",
		prod = "production",
	},
	debug = {
		launch_file = ".vscode/launch.json",
	},
	autocmds = {},
	commands = {},

	db_ui_save_location = "~/.local/share/dbui",
	db_ui_tmp_query_location = "/tmp/dbui",

  codecompanion = {}
}

local project_config = nil
function M.get_project_config()
	if project_config ~= nil then
		return project_config
	end

	local exrc_module = require("user.exrc_manager").get_exrc()
	if exrc_module["project_config"] ~= nil then
		project_config = vim.tbl_extend("force", default_config, exrc_module["project_config"])
		return project_config
	end

	project_config = default_config
	return project_config
end

function M.reset_project_config_cache()
	project_config = nil
end

function M.get_debugger_launch_file()
	return M.get_project_config().debug.launch_file
end

return M
