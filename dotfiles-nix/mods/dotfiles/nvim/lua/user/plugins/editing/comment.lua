local M = {}

function M.setup()
	local status_ok, commentstring = pcall(require, "ts_context_commentstring")
	if not status_ok then
		vim.notify("ts_context_commentstring not found")
		return
	end

	commentstring.setup({
		enable = true,
	})
end

function M.get_keymaps()
	-- No which-key keymaps - uses vim-commentary default keymaps
	return {
		normal = {},
		visual = {},
		shared = {},
	}
end

return M
