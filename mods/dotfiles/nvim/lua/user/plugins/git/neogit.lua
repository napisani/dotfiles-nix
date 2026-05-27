local M = {}

function M.setup()
	-- Configured lazily by the Neogit plugin spec when :Neogit is used.
end

function M.get_keymaps()
	return {
		normal = {},
		visual = {},

		shared = {
			{
				"<leader>go",
				function()
					vim.cmd(":Neogit")
				end,
				desc = "Open neogit",
			},
		},
	}
end

return M
