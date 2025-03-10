local Snacks = require("snacks")
local search_files = require("user.snacks.search_files")
local snacks_common = require("user.snacks.common")
local paste_to_picker = snacks_common.paste_to_picker
local mapping_n = {

	{ "<leader>h", group = "Search" },

	-- {
	-- 	"<leader>hD",
	-- 	"<cmd>lua require('user.telescope').live_grep_git_changed_cmp_base_branch()<CR>",
	-- 	desc = "(D)iff git branch",
	-- },
	{ "<leader>hG", "<cmd>lua require('nvim-github-codesearch').prompt()<cr>", desc = "(G)ithub Code Search" },
	-- { "<leader>hR", "<cmd>lua require('user.telescope').live_grep_in_directory()<CR>", desc = "grep (in directory)" },
	-- { "<leader>hd", "<cmd>lua require('user.telescope').live_grep_git_changed_files()<CR>", desc = "(d)iff git files" },
	-- { "<leader>hq", "<cmd>lua require('user.telescope').live_grep_qflist()<CR>", desc = "grep (q)uicklist" },
	-- { "<leader>hr", "<cmd>lua require('user.telescope').live_grep_from_root()<CR>", desc = "grep from (r)oot" },

	-- {
	-- 	"<leader>hD",
	-- 	"<cmd>lua require('user.telescope').live_grep_git_changed_cmp_base_branch()<CR>",
	-- 	desc = "(D)iff git branch",
	-- },
	-- { "<leader>hG", "<cmd>lua require('nvim-github-codesearch').prompt()<cr>", desc = "(G)ithub Code Search" },
	-- { "<leader>hR", "<cmd>lua require('user.telescope').live_grep_in_directory()<CR>", desc = "grep (in directory)" },
	-- { "<leader>hd", "<cmd>lua require('user.telescope').live_grep_git_changed_files()<CR>", desc = "(d)iff git files" },
	-- { "<leader>hq", "<cmd>lua require('user.telescope').live_grep_qflist()<CR>", desc = "grep (q)uicklist" },
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
	-- {
	-- 	"<leader>hD",
	-- 	'"4y<cmd>lua require("user.telescope").live_grep_git_changed_cmp_base_branch({default_text = vim.fn.getreg("4")})<CR>',
	-- 	desc = "(D)iff git branch",
	-- },
	-- {
	-- 	"<leader>hG",
	-- 	'"y<cmd>lua require("nvim-github-codesearch").prompt()<c-r>4<cr>',
	-- 	desc = "(G)ithub Code Search",
	-- },
	-- {
	-- 	"<leader>hR",
	-- 	'"4y<cmd>lua require("user.telescope").live_grep_in_directory({default_text = vim.fn.getreg("4")})<CR>',
	-- 	desc = "grep (in directory)",
	-- },
	-- {
	-- 	"<leader>hd",
	-- 	'"4y<cmd>lua require("user.telescope").live_grep_git_changed_files({default_text = vim.fn.getreg("4")})<CR>',
	-- 	desc = "(d)iff git files",
	-- },
	-- {
	-- 	"<leader>hq",
	-- 	'"4y<cmd>lua require("user.telescope").live_grep_qflist({default_text = vim.fn.getreg("4")})<CR>',
	-- 	desc = "grep (q)uicklist",
	-- },
	-- {
	-- 	"<leader>hr",
	-- 	'"4y<cmd>lua require("user.telescope").live_grep_from_root({default_text = vim.fn.getreg("4")})<CR>',
	-- 	desc = "grep from (r)oot",
	-- },

	-- { "<leader>/", '"4y/<c-r>4', desc = "search in buffer" },
}

return {
	mapping_n = mapping_n,
	mapping_v = mapping_v,
}
