local M = {}

function M.setup()
	local status_ok, outline = pcall(require, "outline")
	if not status_ok then
		vim.notify("outline not found")
		return
	end

	outline.setup({})
end

function M.get_keymaps()
	return {
		shared = {
			{ "<leader><leader>e", "<cmd>:aboveleft Outline<cr>", desc = "outlin(e)" },
		},
		normal = {},
		visual = {},
	}
end

return M
