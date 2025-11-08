local M = {}

function M.setup()
	local status_ok, npairs = pcall(require, "nvim-autopairs")
	if not status_ok then
		vim.notify("nvim-autopairs not found")
		return
	end

	npairs.setup({
		check_ts = true,
		ts_config = {
			lua = { "string", "source" },
			javascript = { "string", "template_string" },
			java = false,
		},
		disable_filetype = { "TelescopePrompt", "spectre_panel", "snacks_picker_input" },
		fast_wrap = {
			map = "<M-e>",
			chars = { "{", "[", "(", '"', "'" },
			pattern = string.gsub([[ [%'%"%)%>%]%)%}%,] ]], "%s+", ""),
			offset = 0, -- Offset from pattern match
			end_key = "$",
			keys = "qwertyuiopzxcvbnmasdfghjkl",
			check_comma = true,
			highlight = "PmenuSel",
			highlight_grey = "LineNr",
		},
	})
end

function M.get_keymaps()
	-- No which-key keymaps - uses internal fast_wrap keymap <M-e>
	return {
		normal = {},
		visual = {},
		shared = {},
	}
end

return M
