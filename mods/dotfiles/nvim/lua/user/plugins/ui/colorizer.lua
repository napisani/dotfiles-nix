local M = {}

function M.setup()
	local status_ok, colorizer = pcall(require, "colorizer")
	if not status_ok then
		vim.notify("colorizer not found ")
		return
	end
	colorizer.setup()
end

function M.get_keymaps()
	return {
		normal = {},
		visual = {},
		shared = {},
	}
end

return M
