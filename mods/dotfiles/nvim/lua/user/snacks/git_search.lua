local common = require("user.snacks.common")
local utils = require("user.utils")
local M = {}
local cmd = "rg"

function M.live_grep_git_changed_files(opts)
	opts = opts or {}
	local file_list = utils.git_changed_files().get_files()
	local all_opts = vim.tbl_extend("force", opts, {
		cmd = cmd,
		hidden = true,
		ignored = false,
		cwd = utils.get_root_dir(),
	})
	common.live_grep_static_file_list(file_list, all_opts)
end

function M.live_grep_git_changed_cmp_base_branch(opts)
	opts = opts or {}
	local base_branch = utils.get_git_ref()
	local file_list = utils.git_changed_in_branch().get_files(base_branch)
	local all_opts = vim.tbl_extend("force", opts, {
		cmd = cmd,
		hidden = true,
		ignored = false,
		cwd = utils.get_root_dir(),
	})
	common.live_grep_static_file_list(file_list, all_opts)
end
return M
