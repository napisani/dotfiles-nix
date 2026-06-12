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

local vantage_dir = "/Users/nick/code/learn-lsp"

-- Setup lazy.nvim
require("lazy").setup({
	spec = {
		-- -- import your plugins
		-- { import = "plugins" },

		-- Useful lua functions used by lots of plugins
		{ "nvim-lua/plenary.nvim" },

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

		-- Treesitter (main is the active branch; master lags)
		{
			"nvim-treesitter/nvim-treesitter",
			branch = "main",
			lazy = false,
			build = ":TSUpdate",
		},

		-- Git
		{ "lewis6991/gitsigns.nvim" },
		{ "tpope/vim-fugitive" },
		{
			"dlyongemallo/diffview.nvim",
			dependencies = { "nvim-lua/plenary.nvim" },
			config = function()
				require("user.plugins.git.diff").configure_diffview()
			end,
			cmd = {
				"DiffviewOpen",
				"DiffviewClose",
				"DiffviewToggleFiles",
				"DiffviewFocusFiles",
				"DiffviewRefresh",
				"DiffviewFileHistory",
				"DiffviewDiffFiles",
				"DiffviewLog",
			},
		},

		{
			"NeogitOrg/neogit",
			lazy = true,
			cmd = "Neogit",
			opts = {},
			dependencies = {
				"nvim-lua/plenary.nvim", -- required
				"folke/snacks.nvim", -- optional
			},
		},

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

		{
			"MeanderingProgrammer/render-markdown.nvim",
			dependencies = { "nvim-treesitter/nvim-treesitter" },
			ft = { "markdown", "md" },
			opts = {
				file_types = { "markdown", "md" },
			},
		},
		{
			"MSmaili/wiremux.nvim",
			dependencies = {
				"nvim-lua/plenary.nvim",
			},
		},
		{
			"tpope/vim-dadbod",
			lazy = true,
			dependencies = {
				{
					"joryeugene/dadbod-grip.nvim",
					version = "*",
					opts = {
						picker = "snacks",
						keymaps = {
							qpad_execute = "<leader>De",
						},
					},
					config = function(_, opts)
						require("user.plugins.database.dadbod").configure_grip(opts)
					end,
				},
			},
			cmd = {
				"Grip",
				"GripConnect",
				"GripSchema",
				"GripQuery",
				"GripTables",
				"GripStart",
				"GripHistory",
				"GripToggle",
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

		{ "jinh0/eyeliner.nvim" },

		-- for better substitutions/subverts
		{
			"johmsalas/text-case.nvim",
			config = function()
				require("textcase").setup({})
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
		{
			"napisani/nvim-github-codesearch",

			config = function()
				local gh_search = require("nvim-github-codesearch")
				gh_search.setup({
					use_snacks_picker = true,
				})
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

		-- Speech-to-text via OpenAI Whisper
		{
			"kyza0d/vocal.nvim",
			dependencies = {
				"nvim-lua/plenary.nvim",
			},
		},

		-- Inline AI annotations and review lenses
		{
			dir = vantage_dir,
			name = "vantage.nvim",
			build = "npm run compile",
			opts = require("user.plugins.ai.vantage").opts,
			config = function(_, opts)
				require("user.plugins.ai.vantage").configure(opts)
			end,
		},

		-- File manager
		{
			"dmtrKovalenko/fff.nvim",
			lazy = false, -- load at startup so fff's Rust engine is ready before first grep
			build = function()
				require("fff.download").download_or_build_binary()
			end,
		},
	},
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
	install = { colorscheme = { "habamax" } },
	-- automatically check for plugin updates
	checker = { enabled = true },
})
