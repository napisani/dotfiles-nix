local fn = vim.fn

-- Automatically install packer
local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
  PACKER_BOOTSTRAP = fn.system({
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  })
  print("Installing packer close and reopen Neovim...")
  vim.cmd([[packadd packer.nvim]])
end

-- Autocommand that reloads neovim whenever you save the plugins.lua file
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]])

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  return
end

-- Have packer use a popup window
packer.init({
  display = {
    open_fn = function()
      return require("packer.util").float({ border = "rounded" })
    end,
  },
})
local function define_plugins(use)
  -- Have packer manage itself
  use { "wbthomason/packer.nvim", commit = "ea0cc3c59f67c440c5ff0bbe4fb9420f4350b9a3" }

  -- Useful lua functions used by lots of plugins
  use { "nvim-lua/plenary.nvim",commit = "a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683" }

  -- Autopairs, integrates with both cmp and treesitter
  use { "windwp/nvim-autopairs",commit = "78a4507bb9ffc9b00f11ae0ac48243d00cb9194d" }

  use { "tpope/vim-commentary",commit = "c4b8f52cbb7142ec239494e5a2c4a512f92c4d07" }
  use { "JoosepAlviste/nvim-ts-context-commentstring",commit = "6b5f95aa4d24f2c629a74f2c935c702b08dbde62" }
  use { "kyazdani42/nvim-web-devicons",commit = "e612de3d3a41a6b7be47f51e956dddabcbf419d9" }
  use { "echasnovski/mini.icons" }
  use { "kyazdani42/nvim-tree.lua",commit = "4e396b26244444c911b73e9f2f40ae0115351fd1" }
  use { "akinsho/bufferline.nvim",commit = "0b2fd861eee7595015b6561dade52fb060be10c4" }
  use { "moll/vim-bbye", commit = "25ef93ac5a87526111f43e5110675032dbcacf56" }
  use { "nvim-lualine/lualine.nvim",commit = "544dd1583f9bb27b393f598475c89809c4d5e86b" }

  use { "ahmedkhalf/project.nvim", commit = "8c6bad7d22eef1b71144b401c9f74ed01526a4fb" }
  use { "lewis6991/impatient.nvim", commit = "47302af74be7b79f002773011f0d8e85679a7618" }
  use { "lukas-reineke/indent-blankline.nvim",commit = "65e20ab94a26d0e14acac5049b8641336819dfc7" }

  use { "goolord/alpha-nvim",commit = "41283fb402713fc8b327e60907f74e46166f4cfd" }
  use { "folke/which-key.nvim" }

  -- Colorschemes
  -- use { "folke/tokyonight.nvim",commit = "9a01eada39558dc3243278e6805d90e8dff45dc0" }
  -- use { "morhetz/gruvbox",commit = "f1ecde848f0cdba877acb0c740320568252cc482" }
  -- use { "shaunsingh/nord.nvim",commit = "15fbfc38a83980b93e169b32a1bf64757f1e2bf4" }
  use { "rebelot/kanagawa.nvim",commit = "e5f7b8a804360f0a48e40d0083a97193ee4fcc87" }

  -- Cmp
  -- The completion plugin
  use { "hrsh7th/nvim-cmp",commit = "d818fd0624205b34e14888358037fb6f5dc51234" }
  -- buffer completions
  use { "hrsh7th/cmp-buffer", commit = "3022dbc9166796b644a841a02de8dd1cc1d311fa" }
  -- path completions
  use { "hrsh7th/cmp-path", commit = "91ff86cd9c29299a64f968ebb45846c485725f23" }
  -- snippet completions
  use { "saadparwaiz1/cmp_luasnip", commit = "05a9ab28b53f71d1aece421ef32fee2cb857a843" }
  use { "hrsh7th/cmp-nvim-lsp",commit = "39e2eda76828d88b773cc27a3f61d2ad782c922d" }
  use { "hrsh7th/cmp-nvim-lua", commit = "f12408bdb54c39c23e67cab726264c10db33ada8" }
  --use { "hrsh7th/cmp-nvim-lsp-signature-help" }
  use { "erhickey/sig-window-nvim", commit = "606e9dbd1f80646c8d2d1b4384872ec718ddc48a" }

  -- Snippets
  --snippet engine
  use { "L3MON4D3/LuaSnip",commit = "ce0a05ab4e2839e1c48d072c5236cce846a387bc" }
  -- a bunch of snippets to use
  use { "rafamadriz/friendly-snippets",commit = "00ebcaa159e817150bd83bfe2d51fa3b3377d5c4" }

  -- LSP
  use { "neovim/nvim-lspconfig",commit = "1ea7c6126a1aa0121098e4f16c04d5dde1a4ba22" }
  -- simple to use language server installer
  use { "williamboman/mason.nvim",
    run = ":MasonUpdate" -- :MasonUpdate updates registry contents
  }
  use { "williamboman/mason-lspconfig.nvim",commit = "58bc9119ca273c0ce5a66fad1927ef0f617bd81b" }
  -- for formatters and linters
  use { "jose-elias-alvarez/null-ls.nvim", commit = "0010ea927ab7c09ef0ce9bf28c2b573fc302f5a7" }
  use { "RRethy/vim-illuminate",commit = "5eeb7951fc630682c322e88a9bbdae5c224ff0aa" }
  use {
    'creativenull/efmls-configs-nvim',tag = 'v1.*',requires = { 'neovim/nvim-lspconfig' },commit = "1e3210cb48ba14cf154c88c59702dafb321c79db"
  }

  -- Telescope
  use { "nvim-telescope/telescope.nvim",commit = "79552ef8488cb492e0f9d2bf3b4e808f57515e35" }
  use { "nvim-telescope/telescope-file-browser.nvim",commit = "a7ab9a957b17199183388c6f357d614fcaa508e5" }
  use {
    "benfowler/telescope-luasnip.nvim",commit = "11668478677de360dea45cf2b090d34f21b8ae07"
  }

  -- Treesitter
  use {
    "nvim-treesitter/nvim-treesitter",commit = "733fa85db27079ec2757183c5c840ba15a303e1f" }

  -- Git
  use { "lewis6991/gitsigns.nvim",commit = "fc68586dbed6f98add38e02ce3fda233e7382096" }
  use { "tpope/vim-fugitive",commit = "0444df68cd1cdabc7453d6bd84099458327e5513" }
  use {
    "sindrets/diffview.nvim",requires = "nvim-lua/plenary.nvim",commit = "4516612fe98ff56ae0415a259ff6361a89419b0a" }

  use {

    "NeogitOrg/neogit",    requires = {
      "nvim-lua/plenary.nvim",         -- required
      "sindrets/diffview.nvim",        -- optional - Diff integration

      "nvim-telescope/telescope.nvim", -- optional
    },    commit = "af1d8d88f426a4da63c913f3b81a37350dbe8d02"
  }

  -- vim.notify notifications
  use { "rcarriga/nvim-notify",commit = "d333b6f167900f6d9d42a59005d82919830626bf" }

  -- Rust tools
  use { "simrat39/rust-tools.nvim",commit = "676187908a1ce35ffcd727c654ed68d851299d3e" }

  -- vim-rooter - ensures that when opening files/dirs vim's CWD remains the root of the project
  -- use{
  -- 	"notjedi/nvim-rooter.lua",
  -- 	commit = "833e6a37fafb9b2acb6228b9005c680face2a20f",
  -- }

  -- VIM movement addons
  -- adds support using the 's' selector for changing text surroundings
  use { "tpope/vim-surround", commit = "3d188ed2113431cf8dac77be61b842acb64433d9" }
  use {
    "smoka7/hop.nvim",  commit = "036462a345792279c58f2f6445756efab706f04a" }
  -- use 'ggandor/lightspeed.nvim'
  -- use{ "ggandor/leap.nvim", commit = "f7391b5fe9771d788816383ee3c75e0be92022af" }

  -- debugging
  use{ "mfussenegger/nvim-dap",commit = "bc03b83c94d0375145ff5ac6a6dcf28c1241e06f" }
  use{
    "rcarriga/nvim-dap-ui",requires = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },commit = "a5606bc5958db86f8d92803bea7400ee26a8d7e4"  }
  use{ "jayp0521/mason-nvim-dap.nvim",commit = "4ba55f9755ebe8297d92c419b90a946123292ae6" }

  use{ "theHamsta/nvim-dap-virtual-text",commit = "484995d573c0f0563f6a66ebdd6c67b649489615" }
  -- use { "mxsdev/nvim-dap-vscode-js", requires = { "mfussenegger/nvim-dap" } }
  -- use {
  --   "microsoft/vscode-js-debug",
  --   opt = true,
  --   run = "npm install --legacy-peer-deps && npx gulp vsDebugServerBundle && mv dist out"
  -- }

  -- use 'mfussenegger/nvim-dap-python'
  -- use 'ChristianChiarulli/neovim-codicons'

  -- helm syntax highlighting
  -- use { "towolf/vim-helm", commit = "fc2259e1f8836304a0526853ddc3fe27045be39a" }
  -- use 'mortepau/codicons.nvim'

  -- hex colors to actual colors (for css)
  use { "norcalli/nvim-colorizer.lua",commit = "a065833f35a3a7cc3ef137ac88b5381da2ba302e" }

  -- Install neoscopes.
  use { "smartpde/neoscopes",commit = "d9655aa272f22378c1cfccce2a4e9d53f986e414" }

  -- use { "napisani/neoscopes" }
  -- use('/Users/nick/code/neoscopes')
  -- use('/Users/nick/code/nvim-github-codesearch')
  use { 'napisani/nvim-github-codesearch', run = 'nix-shell make' }

  -- use {'napisani/nvim-search-rules' }
  -- use { '/Users/nick/code/nvim-search-rules' }

  -- copilot
  use { "github/copilot.vim",commit = "25f73977033c597d530c7ab0e211d99b60927d2d" }

  use { 'karb94/neoscroll.nvim',commit = "a7f5953dbfbe7069568f2d0ed23a9709a56725ab" }
  use { 'hkupty/iron.nvim',commit = "e6b78ec1bc56eab63b3a9112d348b3d79836b672" }

  use({ "robitx/gp.nvim", commit = "5ec4ff704838ea214c53b0269d31f82b4ea0bee4" })

  -- use ({
  -- "kndndrj/nvim-dbee",
  --   -- "/Users/nick/code/nvim-dbee",
  -- requires = {
  --   "MunifTanjim/nui.nvim",
  -- },
  -- run = function()
  --   -- Install tries to automatically detect the install method.
  --   -- if it fails, try calling it with one of these parameters:
  --   --    "curl", "wget", "bitsadmin", "go"
  --   require("dbee").install()
  -- end,
  -- })
  use {
    'glacambre/firenvim',run = function() vim.fn['firenvim#install'](0) end,commit = "c6e37476ab3b58cf01ababfe80ec9335798e70e5" 
  }

  use {
    "pmizio/typescript-tools.nvim",requires = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },commit =
  "f8c2e0b36b651c85f52ad5c5373ff8b07adc15a7"
  }

  use {
     "yioneko/nvim-vtsls",commit = "45c6dfea9f83a126e9bfc5dd63430562b3f8af16"

  }

  use {
    "tpope/vim-dadbod",
    opt = true,
    requires = {
      "kristijanhusak/vim-dadbod-ui",
      "kristijanhusak/vim-dadbod-completion",
      --[[ "abenz1267/nvim-databasehelper", ]]
    },
    cmd = { "DBUIToggle", "DBUI", "DBUIAddConnection", "DBUIFindBuffer", "DBUIRenameBuffer", "DBUILastQueryInfo" },
  }

  use {
    "alexghergh/nvim-tmux-navigation",commit = "4898c98702954439233fdaf764c39636681e2861" }

  use {
    "stefandtw/quickfix-reflector.vim",
    commit = "6a6a9e28e1713b9e9db99eec1e6672e5666c01b9"
  }

  use {
    "stevearc/oil.nvim",commit = "9e5eb2fcd1dfee2ff30c89273ffff179e42034b9"
  }

  -- use{
  --   '/Users/nick/code/nvim-dadbod-ext',
  --   run = './install.sh',
  --   config = function()
  --     vim.cmd([[
  --       let g:nvim_dadbod_bg_port = '4545'
  --     ]])
  --   end
  -- }

  use { 
    'napisani/nvim-dadbod-bg',
    -- '/Users/nick/code/nvim-dadbod-ext',
    config = function()
      vim.cmd([[
        let g:nvim_dadbod_bg_port = '4545'
        let g:nvim_dadbod_bg_log_file= '/tmp/nvim-dadbod-dbg.log'
      ]])
    end, 
    run = './install.sh'
  }

  -- use('/Users/nick/code/monoscope')
  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end

-- Install your plugins here
return packer.startup(define_plugins)
