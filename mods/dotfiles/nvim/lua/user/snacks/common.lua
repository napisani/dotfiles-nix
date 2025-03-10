local Snacks = require("snacks")
local utils = require("user.utils")
local cmd = "rg"

local M = {}
function M.paste_to_picker(cb)
	-- Copy visual selection to register 4
	vim.cmd('normal! "4y')
	-- Get text from register 4
	local selected_text = vim.fn.getreg("4")
	local p = cb({ pattern = selected_text })
	-- p.input.filter.pattern = selected_text
	return p
end

function M.live_grep_static_file_list(file_list, opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()
	if not file_list or #file_list == 0 then
		-- if there are no files passed then make sure the picker never
		-- matches anything by using a bogus file name
		file_list = { "BOGUS.DONT_MATCH" }
	end

	local all_opts = vim.tbl_extend("force", opts, {
		cmd = cmd,
		glob = file_list,
	})

	utils.debug_log(all_opts)
	return Snacks.picker.grep(all_opts)
end

function M.file_list_to_picker(file_list, opts)
	opts = opts or {}
	local items = {}
	for _, file in ipairs(file_list) do
		table.insert(items, {
			file = file,
		})
	end
	local all_opts = vim.tbl_extend("force", opts, {
		items = items,
	})

	return Snacks.picker.pick(all_opts)
end
return M
