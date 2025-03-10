local Snacks = require("snacks")
local utils = require("user.utils")
local cmd = "rg"

local M = {}
function M.find_path_files(opts)
	opts = opts or {}
	local all_opts = vim.tbl_extend("force", opts, {
		tree = true,
		follow_file = true,
	})
	return Snacks.picker.explorer(all_opts)
	-- TODO implement this
	-- Snacks.picker.files({
	-- 	cmd = cmd,
	-- 	cwd = vim.fn.getcwd(),
	-- 	show_hidden = true,
	-- 	no_ignore = true,
	-- 	args = { "--maxdepth", "1" },
	-- })
end

function M.find_files_from_root(opts)
	opts = opts or {}
	local all_opts = vim.tbl_extend("force", opts, {
		cmd = cmd,
		hidden = true,
		ignored = false,
		cwd = utils.get_root_dir(),
	})
	return Snacks.picker.files(all_opts)
end

M.toggle_explorer_tree = M.find_path_files

return M
