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

function M.live_grep_qflist(opts)
	opts = opts or {}
	local list = vim.fn.getqflist({ all = true })
	if list == nil or list.items == nil or vim.tbl_isempty(list.items) then
		vim.notify("No items in quickfix list")
		return
	end
	local all_opts = vim.tbl_extend("force", opts, {
		cmd = cmd,
		hidden = true,
		ignored = false,
		cwd = utils.get_root_dir(),
	})
	local file_list = {}
	for _, item in ipairs(list.items) do
		if item.text ~= nil then
			table.insert(file_list, item.text)
		end
	end
	common.live_grep_static_file_list(file_list, all_opts)
end

return M
