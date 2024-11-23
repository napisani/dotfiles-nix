return {
	opts = {}, -- for default options, refer to the configuration section for custom setup.
	cmd = "Trouble",
	keys = {
		{
			"<leader>Td",
			"<cmd>Trouble diagnostics toggle<cr>",
			desc = "(o)pen diagnostics",
		},

		{
			"<leader>Tq",
			"<cmd>Trouble qflist<cr>",
			desc = "(q)uickfix Trouble",
		},

		{
			"<leader>Tb",
			"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
			desc = "Buffer Diagnostics (Trouble)",
		},

		{
			"<leader>Tl",
			"<cmd>Trouble lsp toggle focus=false win.position=bottom<cr>",
			desc = "LSP Definitions / references / ... (Trouble)",
		},
	},
}
