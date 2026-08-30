local M = {}

local function nvim_tree_api()
	local ok, api = pcall(require, "nvim-tree.api")
	if not ok then
		return nil
	end
	return api
end

local function open_nvim_tree_buffers()
	local buffers = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == "NvimTree" then
			table.insert(buffers, bufnr)
		end
	end
	return buffers
end

function M.refresh_open_nvim_trees(opts)
	opts = opts or {}
	local api = nvim_tree_api()
	if not api then
		return 0
	end

	local buffers = open_nvim_tree_buffers()
	if opts.focused_only and vim.bo.filetype ~= "NvimTree" then
		return 0
	end
	if #buffers == 0 then
		return 0
	end

	api.tree.reload()
	return #buffers
end

function M.refresh_focused_nvim_tree()
	return M.refresh_open_nvim_trees({ focused_only = true }) > 0
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
	if M.refresh_focused_nvim_tree() then
		return
	end

	if refresh_diffview() then
		return
	end

	reload_current_buffer()
end

function M.all()
	if M.refresh_open_nvim_trees() > 0 then
		return
	end

	if refresh_diffview() then
		return
	end

	reload_all_buffers()
end

return M
