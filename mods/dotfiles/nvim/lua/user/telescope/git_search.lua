local common = require("user.telescope.common")
local utils = require("user.utils")
local M = {}

function M.live_grep_git_changed_files(opts)
	local file_list = utils.git_changed_files().get_files()
	local arg_list = {}
	for _, file in ipairs(file_list) do
		table.insert(arg_list, "--glob")
		table.insert(arg_list, file)
	end

	common.live_grep_static_file_list(opts, arg_list)
end

function M.live_grep_git_changed_cmp_base_branch(opts)
	local base_branch = utils.get_primary_git_branch()
	local file_list = utils.git_changed_in_branch().get_files(base_branch)
	local arg_list = {}
	for _, file in ipairs(file_list) do
		table.insert(arg_list, "--glob")
		table.insert(arg_list, file)
	end
	common.live_grep_static_file_list(opts, arg_list)
end
return M
