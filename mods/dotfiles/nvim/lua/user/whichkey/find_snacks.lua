local Snacks = require("snacks")
local snacks_find_files = require("user.snacks.find_files")
local snacks_git_files = require("user.snacks.git_files")
local snacks_common = require("user.snacks.common")
local paste_to_pattern = snacks_common.paste_to_pattern

local mapping_n = {
	{
		"<leader>fC",
		function()
			snacks_git_files.git_conflicted_files()
		end,
		desc = "(C)onflicts",
	},

	{
		"<leader>fD",
		function()
			snacks_git_files.git_changed_cmp_base_branch()
		end,
		desc = "(D)iff git branch",
	},
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

	-- TODO to legendary ?
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

	{
		"<leader>fd",
		function()
			snacks_git_files.git_changed_files()
		end,
		desc = "(d)iff git files",
	},

	{
		"<leader>fe",
		function()
			Snacks.picker.buffers()
		end,
		desc = "Buffers",
	},
	-- TODO to legenedary
	-- -- { "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Keymaps" },

	-- TODO to legenedary
	-- {
	-- 	"<leader>fo",
	-- 	function()
	-- 		Snacks.picker.colorschemes()
	-- 	end,
	-- 	desc = "Colorschemes",
	-- },
	{
		"<leader>fp",
		function()
			snacks_find_files.find_path_files()
		end,
		desc = "(p)ath files",
	},
	{
		"<leader>fr",
		function()
			snacks_find_files.find_files_from_root()
		end,
		desc = "(f)iles",
	},

	-- TODO figure out how to what to do with snips, right now they are useless to me
	-- { "<leader>fs", "<cmd>Telescope luasnip<cr>", desc = "(s)nippet" },

	{
		"<leader>ft",
		function()
			Snacks.picker.git_files()
		end,
		desc = "gi(t) files",
	},
}

local mapping_v = {

	{ "<leader>f", group = "Find" },

	{
		"<leader>fC",
		function()
			paste_to_pattern(function(opts)
				return snacks_git_files.git_conflicted_files(opts)
			end)
		end,
	},

	{
		"<leader>fD",
		function()
			paste_to_pattern(function(opts)
				return snacks_git_files.git_changed_cmp_base_branch(opts)
			end)
		end,
		desc = "(D)iff git branch",
	},
	{
		"<leader>fM",
		function()
			paste_to_pattern(function(opts)
				return Snacks.picker.man(opts)
			end)
		end,
		desc = "(M)an Pages",
	},
	-- { "<leader>fa", "<cmd>lua require('user.telescope').ai_contexts()<cr>", desc = "(a)i contexts" },

	{
		"<leader>fQ",
		function()
			paste_to_pattern(function(opts)
				return Snacks.picker.help(opts)
			end)
		end,
		desc = "Help",
	},
	{
		"<leader>fR",
		function()
			Snacks.picker.registers()
		end,
		desc = "(R)egisters",
	},
	{ "<leader>fc", desc = "(c)ommands" },
	{ "<leader>fk", "<cmd>Legendary<cr>", desc = "legendary (k)commands" },
	{ "<leader>fc", "<cmd>OverseerRun<CR>", desc = "project (c)ommands" },

	{
		"<leader>fd",
		function()
			paste_to_pattern(function(opts)
				return snacks_git_files.git_changed_files(opts)
			end)
		end,
	},

	{
		"<leader>fe",
		function()
			paste_to_pattern(function(opts)
				return Snacks.picker.buffers(opts)
			end)
		end,
		desc = "Buffers",
	},
	-- TODO to legenedary
	-- { "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Keymaps" },
	-- { "<leader>fo", "<cmd>Telescope colorscheme<cr>", desc = "C(o)lorscheme" },

	-- { "<leader>fp", '"4y<cmd>Telescope file_browser path=%:p:h<CR><c-r>4', desc = "Project" },

	{
		"<leader>fp",
		function()
			paste_to_pattern(function(opts)
				return snacks_find_files.find_path_files(opts)
			end)
		end,
		desc = "(p)ath files",
	},

	{
		"<leader>fr",
		function()
			paste_to_pattern(function(opts)
				return snacks_find_files.find_files_from_root(opts)
			end)
		end,
		desc = "(f)iles",
	},
	-- TODO figure out how to what to do with snips, right now they are useless to me
	-- { "<leader>fs", "<cmd>Telescope luasnip<cr>", desc = "(s)nippet" },

	{
		"<leader>ft",
		function()
			paste_to_pattern(function(opts)
				return Snacks.picker.git_files(opts)
			end)
		end,
		desc = "gi(t) files",
	},
}
return {
	mapping_n = mapping_n,
	mapping_v = mapping_v,
}
