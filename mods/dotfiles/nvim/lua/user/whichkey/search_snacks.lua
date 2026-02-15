local search_files = require("user.snacks.search_files")
local git_search = require("user.snacks.git_search")
local snacks_common = require("user.snacks.common")
local paste_to_search = snacks_common.paste_to_search
local Snacks = require("snacks")

local method_search_opts = {
	search = "Methods",
	filter = {
		default = { "Function", "Method" },
	},
}

local mapping_n = {

	{ "<leader>h", group = "Search" },

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

	{
		"<leader>hm",
		function()
			return Snacks.picker.lsp_symbols(method_search_opts)
		end,
		desc = "lsp (s)ymbols",
	},
	{
		"<leader>hs",
		function()
			return Snacks.picker.lsp_symbols()
		end,
		desc = "lsp (s)ymbols",
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

	{
		"<leader>hm",
		function()
			paste_to_search(function(opts)
				local method_opts = vim.tbl_deep_extend("force", {}, opts or {}, method_search_opts)
				return Snacks.picker.lsp_symbols(method_opts)
			end)
		end,
		desc = "lsp (s)ymbols",
	},
	{
		"<leader>hs",
		function()
			paste_to_search(function(opts)
				return Snacks.picker.lsp_symbols(opts)
			end)
		end,
		desc = "lsp (s)ymbols",
	},

	{
		"<leader>/",
		function()
			-- Yank the current visual selection into register 4
			vim.cmd('normal! "4y')
			-- Start search mode and paste register 4
			local register_content = vim.fn.getreg("4")
			vim.api.nvim_feedkeys("/" .. register_content, "n", false)
		end,
		desc = "search in buffer",
	},
}

return {
	mapping_n = mapping_n,
	mapping_v = mapping_v,
}
