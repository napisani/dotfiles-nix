require("context_nvim").setup({
	enable_history = false,

	cmp = {
		enable = false,
		manual_context_keyword = "@ctx",
	},

	blink = {
		enable = true,
		manual_context_keyword = "@ctx",
	},

	lsp = {
		ignore_sources = {
			"efm/cspell",
		},
	},

	prompts = {
		{
			cmp = "Jesttest",
			name = "jest test suite",
			prompt = "Using the code above, write a jest test suite. Please respond with only code any not explanation",
		},
	},
})
