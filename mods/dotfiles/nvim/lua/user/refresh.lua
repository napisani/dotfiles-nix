local M = {}

local function snacks()
	local ok, Snacks = pcall(require, "snacks")
	if not ok then
		vim.notify("snacks not available", vim.log.levels.WARN)
		return nil
	end

	return Snacks
end

local function refresh_explorer_picker(picker)
	local ok, explorer_actions = pcall(require, "snacks.explorer.actions")
	if not ok then
		vim.notify("snacks explorer actions not available", vim.log.levels.WARN)
		return false
	end

	explorer_actions.actions.explorer_update(picker)
	return true
end

function M.explorer_keys()
	return {
		["<Esc>"] = false,
		["<leader>e"] = "explorer_update",
		["<leader>E"] = "explorer_update",
	}
end

function M.refresh_open_explorer_trees(opts)
	opts = opts or {}
	local Snacks = snacks()
	if not Snacks then
		return 0
	end

	local refreshed = 0
	for _, picker in ipairs(Snacks.picker.get({ source = "explorer" })) do
		if not opts.focused_only or picker:is_focused() then
			if refresh_explorer_picker(picker) then
				refreshed = refreshed + 1
			end
		end
	end

	return refreshed
end

function M.refresh_focused_explorer_tree()
	return M.refresh_open_explorer_trees({ focused_only = true }) > 0
end

local function refresh_diffview()
	local ok, diff = pcall(require, "user.plugins.git.diff")
	if not ok then
		return false
	end

	if diff.is_open() then
		diff.refresh()
		return true
	end

	return false
end

local function reload_current_buffer()
	vim.cmd("edit!")
	vim.notify("Buffer reloaded", vim.log.levels.INFO)
end

local function reload_all_buffers()
	local reloaded = 0
	local failed = 0
	local skipped = 0

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local bufname = vim.api.nvim_buf_get_name(bufnr)
			local buftype = vim.bo[bufnr].buftype

			if buftype == "" and bufname ~= "" then
				if vim.fn.filereadable(bufname) == 1 then
					local current_win = vim.api.nvim_get_current_win()
					local win = vim.fn.bufwinid(bufnr)
					if win ~= -1 then
						vim.api.nvim_set_current_win(win)
					end

					local success, err = pcall(function()
						vim.api.nvim_buf_call(bufnr, function()
							vim.cmd("edit!")
						end)
					end)

					if success then
						reloaded = reloaded + 1
					else
						failed = failed + 1
						vim.notify(
							"Failed to reload " .. vim.fn.fnamemodify(bufname, ":.") .. ": " .. tostring(err),
							vim.log.levels.WARN
						)
					end

					vim.api.nvim_set_current_win(current_win)
				else
					skipped = skipped + 1
				end
			else
				skipped = skipped + 1
			end
		end
	end

	local message = string.format("Reloaded %d buffer(s)", reloaded)
	if failed > 0 then
		message = message .. string.format(", %d failed", failed)
	end
	if skipped > 0 then
		message = message .. string.format(", %d skipped", skipped)
	end

	vim.notify(message, vim.log.levels.INFO)
end

function M.current()
	if M.refresh_focused_explorer_tree() then
		return
	end

	if refresh_diffview() then
		return
	end

	reload_current_buffer()
end

function M.all()
	if M.refresh_open_explorer_trees() > 0 then
		return
	end

	if refresh_diffview() then
		return
	end

	reload_all_buffers()
end

return M
