local Snacks = require("snacks")
local snacks_find_files = require("user.snacks.find_files")

local mapping_n = {
	-- { "<leader>fC", "<cmd>lua require('user.telescope').git_conflicts()<CR>", desc = "(C)onflicts" },

	-- {
	-- 	"<leader>fD",
	-- 	"<cmd>lua require('user.telescope').git_changed_cmp_base_branch()<CR>",
	-- 	desc = "(D)iff git branch",
	-- },
	{
		"<leader>fM",
		function()
			Snacks.picker.man()
		end,
		desc = "(M)an Pages",
	},

	{
		"<leader>fQ",
		function()
			Snacks.picker.help()
		end,
		desc = "Help",
	},

	{ "<leader>fc", desc = "(c)ommands" },

	{
		"<leader>fR",
		function()
			Snacks.picker.registers()
		end,
		desc = "(R)egisters",
	},

	-- legendary commands
	{ "<leader>fc", desc = "(c)ommands" },

	-- todo Snacks.picker.commands() would be helpful to for showing the :commands
	{ "<leader>fk", "<cmd>Legendary<cr>", desc = "legendary (k)commands" },
	{ "<leader>fc", "<cmd>OverseerRun<CR>", desc = "project (c)ommands" },

	-- { "<leader>fd", "<cmd>lua require('user.telescope').git_changed_files()<CR>", desc = "(d)iff git files" },
	-- { "<leader>fe", "<cmd>lua require('user.telescope').search_buffers()<CR>", desc = "Buffers" },
	-- -- { "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Keymaps" },
	-- { "<leader>fo", "<cmd>Telescope colorscheme<cr>", desc = "C(o)lorscheme" },
	{
		"<leader>fp",
		function()
			snacks_find_files.find_path_files()
		end,
		desc = "Project",
	},
	-- { "<leader>fr", "<cmd>lua require('user.telescope').find_files_from_root()<CR>", desc = "(f)iles" },
	-- { "<leader>fs", "<cmd>Telescope luasnip<cr>", desc = "(s)nippet" },
	-- { "<leader>ft", "<cmd>lua require('user.telescope').search_git_files()<CR>", desc = "Git Files" },
}

local mapping_v = {}
return {
	mapping_n = mapping_n,
	mapping_v = mapping_v,
}
