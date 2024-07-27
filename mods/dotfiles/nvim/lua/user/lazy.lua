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

-- Setup lazy.nvim
require("lazy").setup({
	spec = {
		-- -- import your plugins
		-- { import = "plugins" },

		-- Useful lua functions used by lots of plugins
		{ "nvim-lua/plenary.nvim", commit = "a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683" },

		-- Autopairs, integrates with both cmp and treesitter
		{ "windwp/nvim-autopairs", commit = "e38c5d837e755ce186ae51d2c48e1b387c4425c6" },

		{ "tpope/vim-commentary", commit = "c4b8f52cbb7142ec239494e5a2c4a512f92c4d07" },
		{ "JoosepAlviste/nvim-ts-context-commentstring", commit = "6b5f95aa4d24f2c629a74f2c935c702b08dbde62" },
		{ "kyazdani42/nvim-web-devicons", commit = "e612de3d3a41a6b7be47f51e956dddabcbf419d9" },
		{ "echasnovski/mini.icons" },
		{ "kyazdani42/nvim-tree.lua", commit = "4e396b26244444c911b73e9f2f40ae0115351fd1" },
		{ "akinsho/bufferline.nvim", commit = "0b2fd861eee7595015b6561dade52fb060be10c4" },

		-- for deleting buffers without closing windows
		{ "moll/vim-bbye", commit = "25ef93ac5a87526111f43e5110675032dbcacf56" },
		{ "nvim-lualine/lualine.nvim", commit = "544dd1583f9bb27b393f598475c89809c4d5e86b" },

		{ "lukas-reineke/indent-blankline.nvim", commit = "65e20ab94a26d0e14acac5049b8641336819dfc7" },

		{ "goolord/alpha-nvim", commit = "41283fb402713fc8b327e60907f74e46166f4cfd" },
		{ "folke/which-key.nvim" },

		-- Colorschemes
		-- { "folke/tokyonight.nvim",commit = "9a01eada39558dc3243278e6805d90e8dff45dc0" },
		-- { "morhetz/gruvbox",commit = "f1ecde848f0cdba877acb0c740320568252cc482" },
		-- { "shaunsingh/nord.nvim",commit = "15fbfc38a83980b93e169b32a1bf64757f1e2bf4" },
		{ "rebelot/kanagawa.nvim", commit = "e5f7b8a804360f0a48e40d0083a97193ee4fcc87" },

		-- Cmp
		-- The completion plugin
		{ "hrsh7th/nvim-cmp", commit = "d818fd0624205b34e14888358037fb6f5dc51234" },
		-- buffer completions
		{ "hrsh7th/cmp-buffer", commit = "3022dbc9166796b644a841a02de8dd1cc1d311fa" },
		-- path completions
		{ "hrsh7th/cmp-path", commit = "91ff86cd9c29299a64f968ebb45846c485725f23" },
		-- snippet completions
		{ "saadparwaiz1/cmp_luasnip", commit = "05a9ab28b53f71d1aece421ef32fee2cb857a843" },
		{ "hrsh7th/cmp-nvim-lsp", commit = "39e2eda76828d88b773cc27a3f61d2ad782c922d" },
		{ "hrsh7th/cmp-nvim-lua", commit = "f12408bdb54c39c23e67cab726264c10db33ada8" },
		--{ "hrsh7th/cmp-nvim-lsp-signature-help" },
		{ "erhickey/sig-window-nvim", commit = "606e9dbd1f80646c8d2d1b4384872ec718ddc48a" },

		-- Snippets
		--snippet engine
		{ "L3MON4D3/LuaSnip", commit = "ce0a05ab4e2839e1c48d072c5236cce846a387bc" },
		-- a bunch of snippets to
		{ "rafamadriz/friendly-snippets", commit = "00ebcaa159e817150bd83bfe2d51fa3b3377d5c4" },

		-- LSP
		{ "neovim/nvim-lspconfig", commit = "f95d371c1a274f60392edfd8ea5121b42dca736e" },
		-- simple to use language server installer
		{
			"williamboman/mason.nvim",
			build = ":MasonUpdate", -- :MasonUpdate updates registry contents
		},
		{ "williamboman/mason-lspconfig.nvim", commit = "ba9c2f0b93deb48d0a99ae0e8d8dd36f7cc286d6" },
		-- for formatters and linters
		-- { "RRethy/vim-illuminate", commit = "5eeb7951fc630682c322e88a9bbdae5c224ff0aa" },
		{
			"creativenull/efmls-configs-nvim",
			tag = "v1.*",
			dependencies = { "neovim/nvim-lspconfig" },
			commit = "1e3210cb48ba14cf154c88c59702dafb321c79db",
		},

		-- Telescope
		{ "nvim-telescope/telescope.nvim", commit = "10b8a82b042caf50b78e619d92caf0910211973d" },
		{ "nvim-telescope/telescope-file-browser.nvim", commit = "8574946bf6d0d820d7f600f3db808f5900a2ae23" },
		{
			"benfowler/telescope-luasnip.nvim",
			commit = "11668478677de360dea45cf2b090d34f21b8ae07",
		},

		-- Treesitter
		{
			"nvim-treesitter/nvim-treesitter",
			commit = "e265fec94c7dc0c8c64cb86820ff5ad3ee135c7d",
		},

		-- Git
		{ "lewis6991/gitsigns.nvim", commit = "fc68586dbed6f98add38e02ce3fda233e7382096" },
		{ "tpope/vim-fugitive", commit = "0444df68cd1cdabc7453d6bd84099458327e5513" },
		{
			"sindrets/diffview.nvim",
			dependencies = "nvim-lua/plenary.nvim",
			commit = "4516612fe98ff56ae0415a259ff6361a89419b0a",
		},

		{

			"NeogitOrg/neogit",
			dependencies = {
				"nvim-lua/plenary.nvim", -- required
				"sindrets/diffview.nvim", -- optional - Diff integration

				"nvim-telescope/telescope.nvim", -- optional
			},
			commit = "2b74a777b963dfdeeabfabf84d5ba611666adab4",
		},

		-- vim.notify notifications
		{ "rcarriga/nvim-notify", commit = "d333b6f167900f6d9d42a59005d82919830626bf" },

		-- Rust tools
		{ "simrat39/rust-tools.nvim", commit = "676187908a1ce35ffcd727c654ed68d851299d3e" },

		-- vim-rooter - ensures that when opening files/dirs vim's CWD remains the root of the project
		-- use{
		-- 	"notjedi/nvim-rooter.lua",
		-- 	commit = "833e6a37fafb9b2acb6228b9005c680face2a20f",
		-- }

		-- VIM movement addons
		-- adds support using the 's' selector for changing text surroundings
		{ "tpope/vim-surround", commit = "3d188ed2113431cf8dac77be61b842acb64433d9" },
		{
			"smoka7/hop.nvim",
			commit = "036462a345792279c58f2f6445756efab706f04a",
		},

		-- debugging
		{ "mfussenegger/nvim-dap", commit = "bc03b83c94d0375145ff5ac6a6dcf28c1241e06f" },
		{
			"rcarriga/nvim-dap-ui",
			dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
			commit = "a5606bc5958db86f8d92803bea7400ee26a8d7e4",
		},
		{ "jayp0521/mason-nvim-dap.nvim", commit = "4ba55f9755ebe8297d92c419b90a946123292ae6" },

		{ "theHamsta/nvim-dap-virtual-text", commit = "484995d573c0f0563f6a66ebdd6c67b649489615" },

		-- hex colors to actual colors (for css)
		{ "norcalli/nvim-colorizer.lua", commit = "a065833f35a3a7cc3ef137ac88b5381da2ba302e" },

		-- Install neoscopes.
		{ "smartpde/neoscopes", commit = "d9655aa272f22378c1cfccce2a4e9d53f986e414" },

		-- { "napisani/neoscopes" }
		-- ('/Users/nick/code/neoscopes')
		-- ('/Users/nick/code/nvim-github-codesearch')
		{
			"napisani/nvim-github-codesearch",
			-- build = "direnv allow && make"
		},

		-- copilot
		{ "github/copilot.vim", commit = "25f73977033c597d530c7ab0e211d99b60927d2d" },

		{ "karb94/neoscroll.nvim", commit = "a7f5953dbfbe7069568f2d0ed23a9709a56725ab" },
		{ "hkupty/iron.nvim", commit = "e6b78ec1bc56eab63b3a9112d348b3d79836b672" },

		{ "robitx/gp.nvim", commit = "2ecf538c9dd3f502571a109e0d64b803984957d4" },

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
			"yioneko/nvim-vtsls",
			commit = "45c6dfea9f83a126e9bfc5dd63430562b3f8af16",
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
			commit = "4898c98702954439233fdaf764c39636681e2861",
		},

		-- editable quickfix lists
		{
			"stefandtw/quickfix-reflector.vim",
			commit = "6a6a9e28e1713b9e9db99eec1e6672e5666c01b9",
		},

		{
			"stevearc/oil.nvim",
			commit = "71c972fbd218723a3c15afcb70421f67340f5a6d",
		},

		{
			"hedyhli/outline.nvim",
			commit = "2175b6da5b7b5be9de14fd3f54383a17f5e4609c",
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
			-- '/Users/nick/code/nvim-dadbod-ext',
			config = function()
				vim.cmd([[
        let g:nvim_dadbod_bg_port = '4545'
        let g:nvim_dadbod_bg_log_file= '/tmp/nvim-dadbod-dbg.log'
      ]])
			end,
			build = "./install.sh",
		},
	},
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
	install = { colorscheme = { "habamax" } },
	-- automatically check for plugin updates
	checker = { enabled = true },
})
