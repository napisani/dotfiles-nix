local M = {}

function M.setup()
	local status_ok, eyeliner = pcall(require, "eyeliner")
	if not status_ok then
		vim.notify("eyeliner not found ")
		return
	end

	eyeliner.setup({
		-- show highlights only after keypress
		highlight_on_key = true,

		-- dim all other characters if set to true (recommended!)
		dim = false,

		-- add eyeliner to f/F/t/T keymaps;
		-- see section on advanced configuration for more information
		default_keymaps = true,
	})

	local bg = "#fabd2f"
	local fg = "#282828"

	vim.api.nvim_set_hl(0, "EyelinerPrimary", { fg = fg, bg = bg, bold = true, underline = false })
	-- vim.api.nvim_set_hl(0, "EyelinerSecondary", { fg = "#ffffff", underline = true })
end

function M.get_keymaps()
	-- No which-key keymaps - uses internal default_keymaps for f/F/t/T
	return {
		normal = {},
		visual = {},
		shared = {},
	}
end

return M
