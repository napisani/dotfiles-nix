local Snacks = require("snacks")

local find_opts = {
	cmd = "rg",
	hidden = true,
	ignored = false,
}
local M = {}

function M.find_path_files(opts)
	opts = opts or {}
	local all_opts = vim.tbl_extend("force", opts, {
		cmd = "rg",
		tree = true,
		hidden = true,
		ignored = false,
		follow_file = true,
		auto_close = true,
		layout = { preset = "my_horizontal_picker", preview = false },
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
	local all_opts = vim.tbl_extend("force", opts, find_opts)
	return Snacks.picker.files(all_opts)
end

M.toggle_explorer_tree = function()
	Snacks.picker.explorer({
		cmd = "rg",
		tree = true,
		follow_file = true,
		auto_close = true,
		hidden = true,
		ignored = false,
		layout = { preset = "sidebar", preview = false },
	})
end

return M
