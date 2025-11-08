local M = {}

function M.setup()
	local status_ok, notify = pcall(require, "notify")
	if not status_ok then
		return
	end
	vim.notify = notify
end

function M.get_keymaps()
	return {
		normal = {},
		visual = {},
		shared = {},
	}
end

return M
