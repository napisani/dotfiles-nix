local utils = require("user.utils")
local common = require("user.snacks.common")

local M = {}

function M.git_changed_files(opts)
	opts = opts or {}
	local cwd = utils.get_root_dir()
	local file_list = utils.git_changed_files().get_files()
	local all_opts = vim.tbl_extend("force", opts, {
		cwd = cwd,
		items = file_list,
	})
	return common.file_list_to_picker(file_list, all_opts)
end

M.git_changed_cmp_base_branch = function(opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()

	local base_branch = utils.get_git_ref()
	local cmd = { "git" }
	local args = utils.git_changed_in_branch().get_git_args(base_branch)
	for _, arg in ipairs(args) do
		table.insert(cmd, arg)
	end

	local files_list = vim.fn.systemlist(cmd)
	local all_opts = vim.tbl_extend("force", opts, {
		items = files_list,
		cwd = utils.get_root_dir(),
	})
	return common.file_list_to_picker(files_list, all_opts)
end

M.git_conflicted_files = function(opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()
	local cmd = { "git" }
	local args = utils.git_conflicted_files().get_git_args()
	for _, arg in ipairs(args) do
		table.insert(cmd, arg)
	end

	local files_list = vim.fn.systemlist(cmd)
	local all_opts = vim.tbl_extend("force", opts, {
		items = files_list,
		cwd = utils.get_root_dir(),
	})
	return common.file_list_to_picker(files_list, all_opts)
end

return M
