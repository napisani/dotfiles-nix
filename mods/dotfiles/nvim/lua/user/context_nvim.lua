local cmp = require("cmp")

vim.api.nvim_create_autocmd("InsertEnter", {
	group = vim.api.nvim_create_augroup("AddCmpSourceLast", { clear = true }),
	callback = function()
		if vim.bo.filetype ~= "AvanteInput" then
			return
		end
		vim.schedule(function()
			local config = cmp.get_config()
			-- if the table already has a sources key, then we just add the source to the table
			if config == nil or config.sources == nil then
				return
			end

			local filtered = vim.tbl_filter(function(item)
				return type(item) == "table" and item.name == "context_nvim"
			end, config.sources)

			if #filtered > 0 then
				return
			end
			table.insert(config.sources, { name = "context_nvim" })
			cmp.setup.buffer(config)
		end)
	end,
	desc = "Add context_nvim cmp source on InsertEnter",
	pattern = "*",
})

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
      cmp = 'Jesttest',
			name = "jest test suite",
			prompt = "Using the code above, write a jest test suite. Please respond with only code any not explanation",
		},
	},
})
