local Snacks = require("snacks")
local cmd = "rg"

local M = {}
function M.find_path_files()
	Snacks.picker.explorer({
		tree = true,
		follow_file = true,
	})
	-- Snacks.picker.files({
	-- 	cmd = cmd,
	-- 	cwd = vim.fn.getcwd(),
	-- 	show_hidden = true,
	-- 	no_ignore = true,
	-- 	args = { "--maxdepth", "1" },
	-- })
end


M.toggle_explorer_tree = M.find_path_files

return M
