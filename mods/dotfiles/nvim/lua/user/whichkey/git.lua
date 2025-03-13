local gitsigns = require("gitsigns")
local compare = require("user.snacks.compare")

local shared_mappings = {
	{ "<leader>g", group = "Git" },

	{
		"<leader>gr",
		function()
			compare.establish_git_ref()
		end,
		desc = "set (r)ef",
	},

	{
		"<leader>gR",
		function()
			compare.establish_git_ref(true)
		end,
		desc = "set (R)ef commit",
	},

	{
		"<leader>gl",
		function()
			gitsigns.blame_line()
		end,
		desc = "Blame",
	},
	{
		"<leader>gn",
		function()
			gitsigns.next_hunk()
		end,
		desc = "Next Hunk",
	},
	{
		"<leader>go",
		function()
			vim.cmd(":Neogit")
		end,
		desc = "Open neogit",
	},
	{
		"<leader>gp",
		function()
			gitsigns.prev_hunk()
		end,
		desc = "Prev Hunk",
	},
}
local normal_mappings = {}
local visual_mappings = {}

return {
	mapping_v = visual_mappings,
	mapping_n = normal_mappings,
	mapping_shared = shared_mappings,
}
