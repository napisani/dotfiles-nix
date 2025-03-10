local Snacks = require("snacks")
local utils = require("user.utils")
local common = require("user.snacks.common")
local cmd = "rg"

local M = {}

function M.live_grep_from_root(opts)
	-- TODO does not support `search@@**file**` syntax yet
	opts = opts or {}
	local all_opts = vim.tbl_extend("force", opts, {
		cmd = cmd,
		hidden = true,
		ignored = false,
		cwd = utils.get_root_dir(),
	})
	return Snacks.picker.grep(all_opts)
end

function M.live_grep_git_changed_files(opts)
	opts = opts or {}
	local file_list = utils.git_changed_files().get_files()
	local all_opts = vim.tbl_extend("force", opts, {
		cmd = cmd,
		hidden = true,
		ignored = false,
		cwd = utils.get_root_dir(),
	})
	return common.live_grep_static_file_list(file_list, all_opts)
end

return M
