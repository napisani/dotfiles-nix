local file_utils = require("user.utils.file_utils")
local M = {}

local default_config = {
	lint = {},
	branches = {
		main = nil,
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
local dap_root_markers = {
	"package.json",
	"tsconfig.json",
	"jsconfig.json",
	"pyproject.toml",
	"setup.py",
	"setup.cfg",
	"Pipfile",
	"poetry.lock",
	"requirements.txt",
	"go.mod",
	".git",
}

function M.get_project_config()
	if project_config ~= nil then
		return project_config
	end

	local exrc_module = require("user.plugins.util.exrc_manager").get_exrc()
	if exrc_module["project_config"] ~= nil then
		project_config = vim.tbl_extend("force", default_config, exrc_module["project_config"])
		return project_config
	end

	project_config = default_config
	return project_config
end

function M.get_debugger_launch_file(root_dir)
	local launch_file = M.get_project_config().debug.launch_file
	local is_absolute = vim.fs and vim.fs.is_absolute and vim.fs.is_absolute(launch_file)
	if is_absolute == nil then
		is_absolute = launch_file:sub(1, 1) == "/" or launch_file:match("^%a:[/\\]") ~= nil
	end
	if is_absolute then
		return launch_file
	end

	root_dir = root_dir or file_utils.get_root_dir()
	return file_utils.join_path(root_dir, launch_file)
end

function M.get_dap_root(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local start_dir = bufname ~= "" and vim.fs.dirname(bufname) or vim.fn.getcwd()
	local matches = vim.fs.find(dap_root_markers, { path = start_dir, upward = true })
	if matches and matches[1] then
		return vim.fs.dirname(matches[1])
	end
	return file_utils.get_root_dir()
end

return M
