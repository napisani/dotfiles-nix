local builtin = require("telescope.builtin")
local utils = require("user.utils")
local common = require("user.telescope.common")
local M = {}
function M.find_files_from_root(opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()
	local cmd_opts, dir_opts = common.constrain_to_scope()

	local find_command = utils.merge_list(common.ripgrep_base_cmd, { "--files", "--hidden" })
	find_command = utils.merge_list(find_command, common.ignore_globs)
	find_command = utils.merge_list(find_command, cmd_opts)

	opts.find_command = find_command
	opts.search_dirs = opts.search_dirs or {}
	opts.search_dirs = utils.merge_list(opts.search_dirs, dir_opts)

	builtin.find_files(opts)
end
return M
