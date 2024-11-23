local mapping_n = {
	{ "<leader>f", group = "Find" },
	{ "<leader>fC", "<cmd>lua require('user.telescope').git_conflicts()<CR>", desc = "(C)onflicts" },
	{
		"<leader>fD",
		"<cmd>lua require('user.telescope').git_changed_cmp_base_branch()<CR>",
		desc = "(D)iff git branch",
	},
	{ "<leader>fM", "<cmd>Telescope man_pages<cr>", desc = "Man Pages" },

	{ "<leader>fQ", "<cmd>Telescope help_tags<cr>", desc = "Find Help" },
	{ "<leader>fR", "<cmd>Telescope registers<cr>", desc = "Registers" },
	{ "<leader>fS", "<cmd>lua require('user.neoscopes').neoscopes.select()<cr>", desc = "(S)copes" },
	{ "<leader>fc", desc = "(c)ommands" },
	{ "<leader>fk", "<cmd>Legendary<cr>", desc = "legendary (k)commands" },
	{ "<leader>fc", "<cmd>OverseerRun<CR>", desc = "project (c)ommands" },

	{ "<leader>k", "<cmd>Legendary<cr>", desc = "Legendary" },
	{ "<leader>K", "<cmd>OverseerRun<cr>", desc = "Project Command" },

	{ "<leader>fd", "<cmd>lua require('user.telescope').git_changed_files()<CR>", desc = "(d)iff git files" },
	{ "<leader>fe", "<cmd>lua require('user.telescope').search_buffers()<CR>", desc = "Buffers" },
	-- { "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Keymaps" },
	{ "<leader>fo", "<cmd>Telescope colorscheme<cr>", desc = "C(o)lorscheme" },
	{ "<leader>fp", "<cmd>Telescope file_browser path=%:p:h<CR>", desc = "Project" },
	{ "<leader>fr", "<cmd>lua require('user.telescope').find_files_from_root()<CR>", desc = "(f)iles" },
	{ "<leader>fs", "<cmd>Telescope luasnip<cr>", desc = "(s)nippet" },
	{ "<leader>ft", "<cmd>lua require('user.telescope').search_git_files()<CR>", desc = "Git Files" },
}

local mapping_v = {

	{ "<leader>f", group = "Find" },
	{
		"<leader>fC",
		'"4y<cmd>lua require("user.telescope").git_conflicts({default_text = vim.fn.getreg("4")})<CR>',
		desc = "(c)onflicts",
	},
	{
		"<leader>fD",
		'"4y<cmd>lua require("user.telescope").git_changed_cmp_base_branch({default_text = vim.fn.getreg("4")})<CR>',
		desc = "(D)iff git branch",
	},
	{ "<leader>fM", "<cmd>Telescope man_pages<cr>", desc = "Man Pages" },
	{ "<leader>fa", "<cmd>lua require('user.telescope').ai_contexts()<cr>", desc = "(a)i contexts" },
	{ "<leader>fQ", "<cmd>Telescope help_tags<cr>", desc = "Find Help" },
	{ "<leader>fR", "<cmd>Telescope registers<cr>", desc = "Registers" },
	{ "<leader>fS", "<cmd>lua require('user.neoscopes').neoscopes.select()<cr>", desc = "(S)copes" },
	{ "<leader>fc", desc = "(c)ommands" },
	{ "<leader>fcv", "<cmd>Telescope commands<cr>", desc = "neo(v)im commands" },
	{ "<leader>fcp", "<cmd>OverseerRun<CR>", desc = "neo(v)im commands" },
	{
		"<leader>fd",
		'"4y<cmd>lua require("user.telescope").git_changed_files({default_text = vim.fn.getreg("4")})<CR>',
		desc = "(d)iff git files",
	},
	{
		"<leader>fe",
		'"4y<cmd>lua require("user.telescope").search_buffers({default_text = vim.fn.getreg("4")})<CR>',
		desc = "Buffers",
	},
	{ "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Keymaps" },
	{ "<leader>fo", "<cmd>Telescope colorscheme<cr>", desc = "C(o)lorscheme" },
	{ "<leader>fp", '"4y<cmd>Telescope file_browser path=%:p:h<CR><c-r>4', desc = "Project" },
	{
		"<leader>fr",
		'"4y<cmd>lua require("user.telescope").find_files_from_root({default_text = vim.fn.getreg("4")})<CR>',
		desc = "(f)iles",
	},
	{ "<leader>fs", "<cmd>Telescope luasnip<cr>", desc = "(s)nippet" },
	{
		"<leader>ft",
		'"4y<cmd>lua require("user.telescope").search_git_files({default_text = vim.fn.getreg("4")})<CR>',
		desc = "Git Files",
	},
}

return {
	mapping_n = mapping_n,
	mapping_v = mapping_v,
}
