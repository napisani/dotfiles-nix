local M = {}
local api = vim.api

local function diffview_lib()
	-- Navigation must not load the lazy Diffview plugin in ordinary tabs.
	return package.loaded["diffview.lib"]
end

function M.remember_origin(view)
	local lib = diffview_lib()
	local tab = lib and lib.get_prev_non_view_tabpage()
	vim.t[view.tabpage].edit_navigation_origin = tab
end

---Return an editing window for navigation out of a Diffview tab.
---Creates an editing tab only if no ordinary tab survives.
---@param source_tab integer
---@return integer? win
function M.editing_win(source_tab)
	local lib = diffview_lib()
	if not lib or not lib.tabpage_to_view(source_tab) then
		return nil
	end

	local tab = api.nvim_tabpage_is_valid(source_tab) and vim.t[source_tab].edit_navigation_origin or nil
	if not tab or not api.nvim_tabpage_is_valid(tab) or lib.tabpage_to_view(tab) then
		tab = lib.get_prev_non_view_tabpage()
	end
	if not tab then
		vim.cmd.tabnew()
		tab = api.nvim_get_current_tabpage()
	end
	vim.t[source_tab].edit_navigation_origin = tab

	local current = api.nvim_tabpage_get_win(tab)
	local wins = { current }
	vim.list_extend(wins, api.nvim_tabpage_list_wins(tab))
	for _, win in ipairs(wins) do
		local buf = api.nvim_win_get_buf(win)
		if api.nvim_win_get_config(win).relative == "" and vim.bo[buf].buftype == "" then
			return win
		end
	end

	api.nvim_set_current_tabpage(tab)
	vim.cmd.vsplit()
	vim.cmd.enew()
	return api.nvim_get_current_win()
end

---@param source_tab integer
function M.focus_editing_win(source_tab)
	local win = M.editing_win(source_tab)
	if win then
		api.nvim_set_current_win(win)
	end
end

function M.route_picker(picker)
	local source_tab = api.nvim_win_get_tabpage(picker.main)
	local win = M.editing_win(source_tab)
	if win then
		picker.main = win
		api.nvim_set_current_win(win)
		-- Persistent sidebar pickers cannot keep focus across tabpages.
		picker.opts.jump.close = true
	end
	return win
end

function M.picker_jump(picker, item, action)
	if #picker:selected({ fallback = true }) > 0 then
		M.route_picker(picker)
	end
	return require("snacks.picker.actions").jump(picker, item, action)
end

return M
