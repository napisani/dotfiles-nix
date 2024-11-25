require("context_nvim").setup({
	enable_history = false,

	cmp = {
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
