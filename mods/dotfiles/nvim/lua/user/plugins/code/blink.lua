local M = {}

function M.setup()
	-- Blink is configured via lazy.nvim opts
	-- This module exists for consistency and future keymap extraction
end

function M.get_keymaps()
	return {
		shared = {},
		normal = {},
		visual = {},
	}
end

-- Blink configuration options (used by lazy.nvim)
M.opts = {
	-- 'default' for mappings similar to built-in completion
	-- 'super-tab' for mappings similar to vscode (tab to accept, arrow keys to navigate)
	-- 'enter' for mappings similar to 'super-tab' but with 'enter' to accept
	-- See the full "keymap" documentation for information on defining your own keymap.
	keymap = {
		preset = "enter",
		-- ["<CR>"] = { "select_and_accept" },
	},

	completion = {
		list = {
			selection = {
				preselect = false,
			},
		},
	},

	appearance = {
		-- Sets the fallback highlight groups to nvim-cmp's highlight groups
		-- Useful for when your theme doesn't support blink.cmp
		-- Will be removed in a future release
		use_nvim_cmp_as_default = true,
		-- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
		-- Adjusts spacing to ensure icons are aligned
		nerd_font_variant = "mono",
	},

	-- Default list of enabled providers defined so that you can extend it
	-- elsewhere in your config, without redefining it, due to `opts_extend`
	sources = {
		default = { "lsp", "path", "snippets", "buffer" },
		per_filetype = {},
		providers = {},
	},
}

M.opts_extend = { "sources.default" }

return M
