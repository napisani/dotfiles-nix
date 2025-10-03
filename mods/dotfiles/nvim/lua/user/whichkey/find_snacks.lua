local Snacks = require("snacks")
local snacks_find_files = require("user.snacks.find_files")
local snacks_git_files = require("user.snacks.git_files")
local snacks_proctmux = require("user.snacks.proctmux")
local snacks_common = require("user.snacks.common")
local snacks_commands = require("user.snacks.commands.init")
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

	{
		"<leader>fc",
		function()
			snacks_proctmux.show_procmux_commands()
		end,
		desc = "project (c)ommands",
	},

	{
		"<leader>fl",
		function()
			snacks_commands.launch_command()
		end,
		desc = "(l)aunch",
	},

	{
		"<leader>fk",
		function()
			Snacks.picker.commands()
		end,
		desc = "nvim (k)commands",
	},

	{
		"<leader>fm",
		function()
			Snacks.picker.keymaps()
		end,
		desc = "key (m)appings",
	},

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
		desc = "files from (r)oot",
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

	{
		"<leader>fP",
		function()
			Snacks.picker.pickers()
		end,
		desc = "(P)ickers",
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

	{
		"<leader>fc",
		function()
			snacks_proctmux.show_procmux_commands()
		end,
		desc = "project (c)ommands",
	},
	{
		"<leader>fk",
		function()
			snacks_commands.commands_picker()
		end,
		desc = "(k)commands",
	},

	-- {
	-- 	"<leader>fK",
	-- 	function()
	-- 		Snacks.picker.commands()
	-- 	end,
	-- 	desc = "nvim (K)commands",
	-- },

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

	-- {
	-- 	"<leader>fK",
	-- 	function()
	-- 		paste_to_pattern(function(opts)
	-- 			return Snacks.picker.commands(opts)
	-- 		end)
	-- 	end,
	-- 	desc = "nvim (K)commands",
	-- },
}
return {
	mapping_n = mapping_n,
	mapping_v = mapping_v,
}
