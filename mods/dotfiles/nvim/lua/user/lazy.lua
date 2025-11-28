-- Bootstrap lazy.nvim

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = ";"

vim.g.nvim_dadbod_bg_port = "4545"
vim.g.nvim_dadbod_bg_log_file = "/tmp/nvim-dadbod-dbg.log"

-- Setup lazy.nvim
require("lazy").setup({
	spec = {
		-- -- import your plugins
		-- { import = "plugins" },

		-- Useful lua functions used by lots of plugins
		{ "nvim-lua/plenary.nvim" },

		-- Autopairs, integrates with both cmp and treesitter
		{ "windwp/nvim-autopairs" },

		{ "tpope/vim-commentary" },
		{ "JoosepAlviste/nvim-ts-context-commentstring" },
		{ "nvim-tree/nvim-web-devicons", opts = {} },
		{ "echasnovski/mini.icons" },
		{ "akinsho/bufferline.nvim" },

		{ "nvim-lualine/lualine.nvim" },

		{ "lukas-reineke/indent-blankline.nvim" },

		{ "folke/which-key.nvim" },
		{
			"folke/trouble.nvim",
			opts = require("user.trouble").opts,
			cmd = require("user.trouble").cmd,
			keys = require("user.trouble").keys,
		},

		{ "rebelot/kanagawa.nvim" },

		{
			"saghen/blink.cmp",

			-- use a release tag to download pre-built binaries
			version = "*",
			opts = require("user.blink").opts,
			opts_extend = require("user.blink").opts_extend,
		},

		-- Snippets
		--snippet engine
		{ "L3MON4D3/LuaSnip" },
		-- a bunch of snippets to
		{ "rafamadriz/friendly-snippets" },

		-- LSP
		{ "neovim/nvim-lspconfig" },
		-- simple to use language server installer
		{
			"williamboman/mason.nvim",
			build = ":MasonUpdate", -- :MasonUpdate updates registry contents
		},
		{ "williamboman/mason-lspconfig.nvim" },

		-- TODO come back and see if i still need this
		{
			"rachartier/tiny-code-action.nvim",
			dependencies = {
				{ "nvim-lua/plenary.nvim" },
			},
			event = "LspAttach",
			config = function()
				require("tiny-code-action").setup({
					backend = "delta",
				})
			end,
		},
		{
			"folke/snacks.nvim",
			priority = 1000,
			lazy = false,
			opts = require("user.snacks").opts,
		},
		-- for formatters and linters
		{
			"creativenull/efmls-configs-nvim",
			version = "v1.x.x", -- version is optional, but recommended
			dependencies = { "neovim/nvim-lspconfig" },
		},

		-- Treesitter
		{
			"nvim-treesitter/nvim-treesitter",
		},

		-- Git
		{ "lewis6991/gitsigns.nvim" },
		{ "tpope/vim-fugitive" },
		{
			"sindrets/diffview.nvim",
			dependencies = "nvim-lua/plenary.nvim",
		},

		-- come back to this once it can replace diffview
		-- {
		-- 	"esmuellert/vscode-diff.nvim",
		-- 	dependencies = { "MunifTanjim/nui.nvim" },
		-- },

		{

			"NeogitOrg/neogit",
			dependencies = {
				"nvim-lua/plenary.nvim", -- required
				"sindrets/diffview.nvim", -- optional - Diff integration

				"nvim-telescope/telescope.nvim", -- optional
			},
		},

		-- java
		{ "nvim-java/nvim-java" },

		{
			"kylechui/nvim-surround",
			version = "*", -- Use for stability; omit to use `main` branch for the latest features
			event = "VeryLazy",
			config = function()
				require("nvim-surround").setup({
					-- Configuration here, or leave empty to use defaults
				})
			end,
		},
		{
			"smoka7/hop.nvim",
		},

		-- debugging
		{ "mfussenegger/nvim-dap" },
		{
			"rcarriga/nvim-dap-ui",
			dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
		},
		{ "jayp0521/mason-nvim-dap.nvim" },

		{ "theHamsta/nvim-dap-virtual-text" },

		-- hex colors to actual colors (for css)
		{ "norcalli/nvim-colorizer.lua" },

		-- copilot
		{ "github/copilot.vim" },

		-- 		{
		-- 			"folke/sidekick.nvim",
		-- 			opts = require("user.sidekick").opts,
		-- 			keys = require("user.sidekick").keys,
		-- 		},
		{
			"sudo-tee/opencode.nvim",
			config = function()
				require("opencode").setup(require("user.opencode"))
			end,
			dependencies = {
				"nvim-lua/plenary.nvim",
				{
					"MeanderingProgrammer/render-markdown.nvim",
					opts = {
						anti_conceal = { enabled = false },
						file_types = { "markdown", "opencode_output" },
					},
					ft = { "markdown", "Avante", "copilot-chat", "opencode_output" },
				},
				-- Optional, for file mentions and commands completion, pick only one
				"saghen/blink.cmp",

				-- Optional, for file mentions picker, pick only one
				"folke/snacks.nvim",
			},
		},

		{
			"olimorris/codecompanion.nvim",
			config = true,
			dependencies = {
				"nvim-lua/plenary.nvim",
				"nvim-treesitter/nvim-treesitter",
			},
		},
		{
			"ravitemer/mcphub.nvim",
			dependencies = {
				"nvim-lua/plenary.nvim",
			},
			build = "bundled_build.lua", -- Bundles `mcp-hub` binary along with the neovim plugin
			config = function()
				require("mcphub").setup({
					use_bundled_binary = true,
				})
			end,
		},

		{
			"napisani/context-nvim",
		},

		-- {
		-- 	"yioneko/nvim-vtsls",
		-- },

		{
			"tpope/vim-dadbod",
			opt = true,
			dependencies = {
				"kristijanhusak/vim-dadbod-ui",
				"kristijanhusak/vim-dadbod-completion",
				--[[ "abenz1267/nvim-databasehelper", ]]
			},
			cmd = {
				"DBUIToggle",
				"DBUI",
				"DBUIAddConnection",
				"DBUIFindBuffer",
				"DBUIRenameBuffer",
				"DBUILastQueryInfo",
			},
		},

		{
			"alexghergh/nvim-tmux-navigation",
		},

		-- editable quickfix lists
		{
			"stefandtw/quickfix-reflector.vim",
		},

		{
			"stevearc/oil.nvim",
		},

		{
			"hedyhli/outline.nvim",
		},

		{ "jinh0/eyeliner.nvim" },

		-- for better substitutions/subverts
		{
			"johmsalas/text-case.nvim",
			dependencies = { "nvim-telescope/telescope.nvim" },
			config = function()
				require("textcase").setup({})
				require("telescope").load_extension("textcase")
			end,
			-- If you want to use the interactive feature of the `Subs` command right away, text-case.nvim
			-- has to be loaded on startup. Otherwise, the interactive feature of the `Subs` will only be
			-- available after the first executing of it or after a keymap of text-case.nvim has been used.
			lazy = false,
		},

		{
			"jpalardy/vim-slime",
			config = function()
				vim.g.slime_target = "tmux"
				vim.g.slime_cell_delimiter = "# %%"
				vim.g.slime_bracketed_paste = 1
			end,
		},

		-- {
		--   '/Users/nick/code/nvim-dadbod-ext',
		--   build = './install.sh',
		--   config = function()
		--     vim.cmd([[
		--       let g:nvim_dadbod_bg_port = '4545'
		--     ]])
		--   end
		-- }

		{
			"napisani/nvim-dadbod-bg",
			-- dir = "/Users/nick/code/nvim-dadbod-bg",
			build = "./install.sh",
		},
		-- Neovim dev plugins
		{
			"folke/lazydev.nvim",
			ft = "lua", -- only load on lua files
			opts = {
				library = {
					-- See the configuration section for more details
					-- Load luvit types when the `vim.uv` word is found
					{ path = "luvit-meta/library", words = { "vim%.uv" } },
				},
			},
		},
		{ "Bilal2453/luvit-meta", lazy = true }, -- optional `vim.uv` typings
	},
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
	install = { colorscheme = { "habamax" } },
	-- automatically check for plugin updates
	checker = { enabled = true },
})
