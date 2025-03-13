local utils = require("user.utils")

local normal_mappings = {
	{ "<leader>c", group = "Changes" },

	{
		"<leader>cr",
		function()
			vim.cmd("DiffviewOpen " .. utils.get_git_ref())
		end,
		desc = "compare to ref",
	},

	{ "<leader>cB", "<Cmd>:G blame<CR>", desc = "Blame" },
	{ "<leader>cH", "<Cmd>:DiffviewOpen HEAD<CR>", desc = "diff (H)ead" },
	{ "<leader>ch", "<Cmd>:DiffviewFileHistory<CR>", desc = "(h)istory" },
	{ "<leader>co", "<Cmd>:DiffviewOpen<CR>", desc = "Open" },
	{ "<leader>cq", "<Cmd>:DiffviewClose<CR>", desc = "DiffviewClose" },
	{ "<leader>cx", '<Cmd>call feedkeys("dx")<CR>', desc = "Choose DELETE" },

	{ "<leader>cf", group = "(F)ile" },
	{ "<leader>cfH", "<Cmd>:DiffviewOpen HEAD -- %<CR>", desc = "diff (H)ead" },
	{
		"<leader>cfm",
		function()
			local ref = utils.get_git_ref()
			vim.cmd("DiffviewOpen " .. ref .. " -- %")
		end,
		desc = "compare to ref",
	},
	{
		"<leader>cff",
		"<cmd>lua require('user.snacks.compare').find_file_from_root_to_compare_to()<CR>",
		desc = "(f)ile",
	},
	{ "<leader>cfh", "<Cmd>:DiffviewFileHistory --follow %<CR>", desc = "(h)istory" },

	-- changes
	{ "<leader>cfc", "<cmd>CompareClipboard<cr>", desc = "compare (c)lipboard" },
}

local visual_mappings = {
	{ "<leader>c", group = "Changes" },
	{ "<leader>cc", "<esc><cmd>CompareClipboardSelection<cr>", desc = "compare (c)lipboard" },
	{
		"<leader>ch",
		"<Esc><Cmd>'<,'>DiffviewFileHistory --follow<CR>",
		desc = "(h)istory",
	},
}

return {
	mapping_v = visual_mappings,
	mapping_n = normal_mappings,
	mapping_shared = {},
}
