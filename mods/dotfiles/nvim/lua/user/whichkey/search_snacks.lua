local search_files = require("user.snacks.search_files")
local git_search = require("user.snacks.git_search")
local snacks_common = require("user.snacks.common")
local paste_to_search = snacks_common.paste_to_search
local mapping_n = {

	{ "<leader>h", group = "Search" },

	{ "<leader>hG", "<cmd>lua require('nvim-github-codesearch').prompt()<cr>", desc = "(G)ithub Code Search" },
	-- { "<leader>hR", "<cmd>lua require('user.telescope').live_grep_in_directory()<CR>", desc = "grep (in directory)" },
	{
		"<leader>hd",
		function()
			git_search.live_grep_git_changed_files()
		end,
		desc = "(d)iff git files",
	},

	{
		"<leader>hq",
		function()
			search_files.live_grep_qflist()
		end,
		desc = "grep (q)uicklist",
	},
	-- { "<leader>hr", "<cmd>lua require('user.telescope').live_grep_from_root()<CR>", desc = "grep from (r)oot" },

	{
		"<leader>hD",
		function()
			git_search.live_grep_git_changed_cmp_base_branch()
		end,
		desc = "(D)iff git branch",
	},
	-- { "<leader>hR", "<cmd>lua require('user.telescope').live_grep_in_directory()<CR>", desc = "grep (in directory)" },
	{
		"<leader>hr",
		function()
			search_files.live_grep_from_root()
		end,
		desc = "grep from (r)oot",
	},
}

local mapping_v = {
	{ "<leader>h", group = "Search" },
	{
		"<leader>hD",
		function()
			paste_to_search(function(opts)
				return git_search.live_grep_git_changed_cmp_base_branch(opts)
			end)
		end,
		desc = "(D)iff git branch",
	},
	{
		"<leader>hG",
		'"4y<cmd>lua require("nvim-github-codesearch").prompt()<c-r>4<cr>',
		desc = "(G)ithub Code Search",
	},
	-- {
	-- 	"<leader>hR",
	-- 	'"4y<cmd>lua require("user.telescope").live_grep_in_directory({default_text = vim.fn.getreg("4")})<CR>',
	-- 	desc = "grep (in directory)",
	-- },
	{
		"<leader>hd",
		function()
			paste_to_search(function(opts)
				return git_search.live_grep_git_changed_files(opts)
			end)
		end,
		desc = "(d)iff git files",
	},

	{
		"<leader>hq",
		function()
			paste_to_search(function(opts)
				return search_files.live_grep_qflist(opts)
			end)
		end,
		desc = "grep (q)uicklist",
	},

	{
		"<leader>hr",
		function()
			paste_to_search(function(opts)
				return search_files.live_grep_from_root(opts)
			end)
		end,
		desc = "grep from (r)oot",
	},

	-- { "<leader>/", '"4y/<c-r>4', desc = "search in buffer" },
}

return {
	mapping_n = mapping_n,
	mapping_v = mapping_v,
}
