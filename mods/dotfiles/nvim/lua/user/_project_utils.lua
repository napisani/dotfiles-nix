
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
}

local project_config = nil
function M.get_project_config()
	if project_config ~= nil then
		return project_config
	end
	local nvim_rc = file_utils.get_root_dir() .. "/.nvimrc.json"
	local json_file = file_utils.read_json_file(nvim_rc)
	if json_file == nil then
		project_config = default_config
		return project_config
	end
	local settings = {}
	for k, v in pairs(default_config) do
		settings[k] = v
		if json_file[k] ~= nil then
			settings[k] = json_file[k]
		end
	end
	project_config = settings
	return settings
end

function M.reset_project_config_cache()
	project_config = nil
end


function M.get_debugger_launch_file()
	return M.get_project_config().debug.launch_file
end

return M
