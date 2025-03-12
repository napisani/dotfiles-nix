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
vim.g.maplocalleader = " "

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
		{ "kyazdani42/nvim-web-devicons" },
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

		-- CMP related
		-- -- The completion plugin
		-- {
		-- 	"hrsh7th/nvim-cmp",
		-- 	opts = function(_, opts)
		-- 		opts.sources = opts.sources or {}
		-- 		-- add lazydev source to the beginning of the list
		-- 		table.insert(opts.sources, {
		-- 			name = "lazydev",
		-- 			group_index = 0, -- set group index to 0 to skip loading LuaLS completions
		-- 		})
		-- 	end,
		-- },

		-- -- buffer completions
		-- { "hrsh7th/cmp-buffer" },
		-- -- path completions
		-- { "hrsh7th/cmp-path" },
		-- -- snippet completions
		-- { "saadparwaiz1/cmp_luasnip" },
		-- { "hrsh7th/cmp-nvim-lsp" },
		-- { "hrsh7th/cmp-nvim-lua" },

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

		-- Telescope deprecated
		-- { "nvim-telescope/telescope.nvim" },
		-- { "nvim-telescope/telescope-file-browser.nvim" },
		-- {
		-- 	"benfowler/telescope-luasnip.nvim",
		-- },
		-- {
		-- 	"nvim-telescope/telescope-fzf-native.nvim",
		-- 	build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release",
		-- },

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

		{

			"NeogitOrg/neogit",
			dependencies = {
				"nvim-lua/plenary.nvim", -- required
				"sindrets/diffview.nvim", -- optional - Diff integration

				"nvim-telescope/telescope.nvim", -- optional
			},
		},

		-- Rust tools
		{ "simrat39/rust-tools.nvim" },

		-- java
		{ "nvim-java/nvim-java" },

		-- vim-rooter - ensures that when opening files/dirs vim's CWD remains the root of the project
		-- use{
		-- 	"notjedi/nvim-rooter.lua",
		--
		-- }

		-- VIM movement addons
		-- {
		-- 	"echasnovski/mini.surround",
		-- 	version = "*",
		-- },
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

		-- Install neoscopes.
		-- Telescope deperecated
		-- { "smartpde/neoscopes" },

		-- { "napisani/neoscopes" }
		-- ('/Users/nick/code/neoscopes')
		-- ('/Users/nick/code/nvim-github-codesearch')
		{
			"napisani/nvim-github-codesearch",
			-- build = "direnv allow && make"
		},

		-- copilot
		{ "github/copilot.vim" },

		-- {
		-- 	"supermaven-inc/supermaven-nvim",
		-- 	config = function()
		-- 		require("supermaven-nvim").setup({})
		-- 	end,
		-- },

		-- { "karb94/neoscroll.nvim" },
		{ "hkupty/iron.nvim" },

		-- { "robitx/gp.nvim" },
		{
			"olimorris/codecompanion.nvim",
			config = true,
			dependencies = {
				"nvim-lua/plenary.nvim",
				"nvim-treesitter/nvim-treesitter",
			},
		},
		-- {
		-- 	"yetone/avante.nvim",
		-- 	-- dir = "/Users/nick/code/avante.nvim",
		-- 	event = "VeryLazy",
		-- 	lazy = false,
		-- 	version = false, -- set this if you want to always pull the latest change
		-- 	opts = require("user.avante"),
		-- 	-- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
		-- 	build = "make",
		-- 	-- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
		-- 	dependencies = {
		-- 		"nvim-treesitter/nvim-treesitter",
		-- 		"stevearc/dressing.nvim",
		-- 		"nvim-lua/plenary.nvim",
		-- 		"MunifTanjim/nui.nvim",
		-- 		--- The below dependencies are optional,
		-- 		"nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
		-- 		"zbirenbaum/copilot.lua", -- for providers='copilot'
		-- 		{
		-- 			-- support for image pasting
		-- 			"HakonHarnes/img-clip.nvim",
		-- 			event = "VeryLazy",
		-- 			opts = {
		-- 				-- recommended settings
		-- 				default = {
		-- 					embed_image_as_base64 = false,
		-- 					prompt_for_file_name = false,
		-- 					drag_and_drop = {
		-- 						insert_mode = true,
		-- 					},
		-- 					-- required for Windows users
		-- 					use_absolute_path = true,
		-- 				},
		-- 			},
		-- 		},
		-- 		{
		-- 			-- Make sure to set this up properly if you have lazy=true
		-- 			"MeanderingProgrammer/render-markdown.nvim",
		-- 			opts = {
		-- 				file_types = { "markdown", "Avante" },
		-- 			},
		-- 			ft = { "markdown", "Avante" },
		-- 		},
		-- 	},
		-- },

		{
			"napisani/context-nvim",
			-- dir = "/Users/nick/code/context-nvim",
			-- name = "context-nvim",
			-- dev = true,
		},

		-- ({
		-- "kndndrj/nvim-dbee",
		--   -- "/Users/nick/code/nvim-dbee",
		-- dependencies = {
		--   "MunifTanjim/nui.nvim",
		-- },
		-- build = function()
		--   -- Install tries to automatically detect the install method.
		--   -- if it fails, try calling it with one of these parameters:
		--   --    "curl", "wget", "bitsadmin", "go"
		--   require("dbee").install()
		-- end,
		-- })

		{
			"kopecmaciej/vi-mongo.nvim",
			config = function()
				require("vi-mongo").setup()
			end,
			cmd = { "ViMongo" },
			keys = {
				{ "<leader>Dm", "<cmd>ViMongo<cr>", desc = "ViMongo" },
			},
		},

		{
			"yioneko/nvim-vtsls",
		},

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
			"stevearc/overseer.nvim",
			opts = {},
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
