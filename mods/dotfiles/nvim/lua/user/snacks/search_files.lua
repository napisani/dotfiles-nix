local Snacks = require("snacks")
local utils = require("user.utils")
local cmd = "rg"

local M = {}

function M.live_grep_from_root(opts)
	opts = opts or {}
	local all_opts = vim.tbl_extend("force", opts, {
		cmd = cmd,
		hidden = true,
		ignored = false,
		cwd = utils.get_root_dir(),
	})
	return Snacks.picker.grep(all_opts)
end

return M
