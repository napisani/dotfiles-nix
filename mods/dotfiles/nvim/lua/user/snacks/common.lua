local Snacks = require("snacks")
local utils = require("user.utils")
local cmd = "rg"

local M = {}
function M.paste_to_pattern(cb)
	vim.cmd('normal! "4y')
	local selected_text = vim.fn.getreg("4")
	local p = cb({ pattern = selected_text })
	return p
end

function M.paste_to_search(cb)
	vim.cmd('normal! "4y')
	local selected_text = vim.fn.getreg("4")
	local p = cb({ search = selected_text })
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

	return Snacks.picker.grep(all_opts)
end

function M.file_list_to_picker(file_list, opts)
	opts = opts or {}
	local cwd = opts.cwd or utils.get_root_dir()
	local items = {}
	for _, file in ipairs(file_list) do
		-- Resolve to absolute path so Snacks opens the correct file
		-- regardless of Neovim's process cwd (handles subdir sessions & worktrees).
		local abs_file
		if file:sub(1, 1) == "/" then
			abs_file = file
		else
			abs_file = cwd .. "/" .. file
		end
		table.insert(items, {
			file = abs_file,
			text = file, -- display the relative path for readability
		})
	end
	local all_opts = vim.tbl_extend("force", opts, {
		items = items,
	})

	return Snacks.picker.pick(all_opts)
end

function M.open_file_keep_picker_focus(picker, item)
	if not picker or not item or item.dir then
		return false
	end

	local path = Snacks.picker.util.path(item) or item.file
	if not path then
		return false
	end

	local list_win = picker.list and picker.list.win and picker.list.win.win
	local target_win = picker.main

	local function is_edit_target(win)
		return win
			and vim.api.nvim_win_is_valid(win)
			and win ~= list_win
			and vim.api.nvim_win_get_config(win).relative == ""
	end

	if not is_edit_target(target_win) then
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if is_edit_target(win) then
				target_win = win
				break
			end
		end
	end

	if not is_edit_target(target_win) then
		vim.notify("No editor window available for " .. vim.fn.fnamemodify(path, ":~:."), vim.log.levels.WARN)
		return false
	end

	local bufnr = item.buf or vim.fn.bufadd(path)
	vim.bo[bufnr].buflisted = true

	vim.api.nvim_win_call(target_win, function()
		vim.cmd("buffer " .. bufnr)
		if item.pos and item.pos[1] > 0 then
			vim.api.nvim_win_set_cursor(0, { item.pos[1], item.pos[2] or 0 })
			vim.cmd("normal! zzzv")
		end
	end)

	if list_win and vim.api.nvim_win_is_valid(list_win) then
		vim.api.nvim_set_current_win(list_win)
	end

	return true
end

return M
