local file_utils = require("user._file_utils")
local M = {}

local base_filename = ".nvimrc.yml"

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
}

local project_config = nil
function M.get_project_config()
	if project_config ~= nil then
		return project_config
	end
	local nvim_rc = file_utils.get_root_dir() .. "/" .. base_filename
	local yaml_data = file_utils.read_yaml_file(nvim_rc)
	if yaml_data == nil then
		project_config = default_config
		return project_config
	end
	return vim.tbl_extend("force", default_config, yaml_data)
end

function M.reset_project_config_cache()
	project_config = nil
end

function M.get_debugger_launch_file()
	return M.get_project_config().debug.launch_file
end

function M.init_nvim_rc()
	local nvim_rc = file_utils.get_root_dir() .. "/" .. base_filename
	local content = [[
lint: {}
# - 'prettier'
# - 'eslint'
branches:
  main: "main"
  prod: "production"
debug:
  launch_file: ".vscode/launch.json"
autocmds: {} 
#  - event: BufWritePre
#    pattern: "*.lua"
#    command: lua vim.notify("Saving file")
commands: {}
#  - command: echo "Hello" 
#    description: print hello 
  ]]
	file_utils.write_string_to_file(nvim_rc, content)
end

return M
