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
  use { "wbthomason/packer.nvim", commit = "1d0cf98a561f7fd654c970c49f917d74fafe1530" }

  -- Useful lua functions used by lots of plugins
  use { "nvim-lua/plenary.nvim",commit = "9ac3e9541bbabd9d73663d757e4fe48a675bb054" }

  -- Autopairs, integrates with both cmp and treesitter
  use { "windwp/nvim-autopairs",commit = "7747bbae60074acf0b9e3a4c13950be7a2dff444" }

  use { "tpope/vim-commentary", commit = "e87cd90dc09c2a203e13af9704bd0ef79303d755" }
  use { "JoosepAlviste/nvim-ts-context-commentstring",commit = "0bf8fbc2ca8f8cdb6efbd0a9e32740d7a991e4c3" }
  use { "kyazdani42/nvim-web-devicons",commit = "986875b7364095d6535e28bd4aac3a9357e91bbe" }
  use { "kyazdani42/nvim-tree.lua",commit = "736c7ff59065275f0483af4b7f07a9bc41449ad0" }
  use { "akinsho/bufferline.nvim",commit = "1952c33e425ede785d26aa9e250addfe304a8510" }
  use { "moll/vim-bbye", commit = "25ef93ac5a87526111f43e5110675032dbcacf56" }
  use { "nvim-lualine/lualine.nvim",commit = "05d78e9fd0cdfb4545974a5aa14b1be95a86e9c9" }

  use { "ahmedkhalf/project.nvim",commit = "8c6bad7d22eef1b71144b401c9f74ed01526a4fb" }
  use { "lewis6991/impatient.nvim",commit = "47302af74be7b79f002773011f0d8e85679a7618" }
  use { "lukas-reineke/indent-blankline.nvim", commit = "018bd04d80c9a73d399c1061fa0c3b14a7614399" }
  use { "goolord/alpha-nvim",commit = "1838ae926e8d49fe5330d1498ee8289ae2c340bc" }
  use { "folke/which-key.nvim" }

  -- Colorschemes
  use { "folke/tokyonight.nvim",commit = "df13e3268a44f142999fa166572fe95a650a0b37" }
  use { "lunarvim/darkplus.nvim",commit = "7c236649f0617809db05cd30fb10fed7fb01b83b" }
  use { "morhetz/gruvbox", commit = "bf2885a95efdad7bd5e4794dd0213917770d79b7" }
  use { "shaunsingh/nord.nvim",commit = "fab04b2dd4b64f4b1763b9250a8824d0b5194b8f" }
  -- " intellj idea darcula-solid
  use { "doums/darcula", commit = "faf8dbab27bee0f27e4f1c3ca7e9695af9b1242b" }
  use { "briones-gabriel/darcula-solid.nvim", commit = "d950b9ca20096313c435a93e57af7815766f3d3d" }
  use { "rebelot/kanagawa.nvim",commit = "42c33239b0460cbbcdb67bc9c7f0c420a95208e6" }

  -- Cmp
  -- The completion plugin
  use { "hrsh7th/nvim-cmp",commit = "3ac8d6cd29c74ff482d8ea47d45e5081bfc3f5ad" }
  -- buffer completions
  use { "hrsh7th/cmp-buffer", commit = "3022dbc9166796b644a841a02de8dd1cc1d311fa" }
  -- path completions
  use { "hrsh7th/cmp-path", commit = "91ff86cd9c29299a64f968ebb45846c485725f23" }
  -- snippet completions
  use { "saadparwaiz1/cmp_luasnip", commit = "18095520391186d634a0045dacaa346291096566" }
  use { "hrsh7th/cmp-nvim-lsp", commit = "0e6b2ed705ddcff9738ec4ea838141654f12eeef" }
  use { "hrsh7th/cmp-nvim-lua",commit = "f12408bdb54c39c23e67cab726264c10db33ada8" }
  --use { "hrsh7th/cmp-nvim-lsp-signature-help" }
  use { "erhickey/sig-window-nvim", commit = "e2984f7c95ebc38fe43635d3951f40a29a79b069" }

  -- Snippets
  --snippet engine
  use { "L3MON4D3/LuaSnip",commit = "ec7fba1d119fb5090a901eb616145450ffb95e31" }
  -- a bunch of snippets to use
  use { "rafamadriz/friendly-snippets",commit = "f674dae71b9daf5ba4a4daf0734f7780417237b1" }

  -- LSP
  use { "neovim/nvim-lspconfig",commit = "6f1d124bbcf03c4c410c093143a86415f46d16a0" }
  -- simple to use language server installer
  use { "williamboman/mason.nvim",
    run = ":MasonUpdate" -- :MasonUpdate updates registry contents
  }
  use { "williamboman/mason-lspconfig.nvim",commit = "c55d18f3947562e699d34d89681edbf9f0e250d3" }
  -- for formatters and linters
  use { "jose-elias-alvarez/null-ls.nvim",commit = "77e53bc3bac34cc273be8ed9eb9ab78bcf67fa48" }
  use { "RRethy/vim-illuminate", commit = "a2907275a6899c570d16e95b9db5fd921c167502" }

  -- Telescope
  use { "nvim-telescope/telescope.nvim",commit = "40c31fdde93bcd85aeb3447bb3e2a3208395a868" }
  use { "nvim-telescope/telescope-file-browser.nvim",commit = "1aa7f12ce797bb5b548c96f38b2c93911e97c543" }
  use {
    "benfowler/telescope-luasnip.nvim",
    commit = "849c4ee1951f34041a26744d2a88284545564ff0"
  }

  -- Treesitter
  use {
    "nvim-treesitter/nvim-treesitter",commit = "dad1b7cd6606ffaa5c283ba73d707b4741a5f445" }

  -- Git
  use { "lewis6991/gitsigns.nvim"  }
  use { "tpope/vim-fugitive",commit = "5f0d280b517cacb16f59316659966c7ca5e2bea2" }
  -- use { 'idanarye/vim-merginal' }
  use {
    "sindrets/diffview.nvim",requires = "nvim-lua/plenary.nvim",commit = "15861892ce62d8f4ab6e72bc4ff5b829f994430a" }

  -- vim.notify notifications
  use { "rcarriga/nvim-notify",commit = "f3024b912073774111202f5fa6518b0cd2a74432" }

  -- Rust tools
  use { "simrat39/rust-tools.nvim", commit = "71d2cf67b5ed120a0e31b2c8adb210dd2834242f" }

  -- vim-rooter - ensures that when opening files/dirs vim's CWD remains the root of the project
  -- use{
  -- 	"notjedi/nvim-rooter.lua",
  -- 	commit = "833e6a37fafb9b2acb6228b9005c680face2a20f",
  -- }

  -- VIM movement addons
  -- adds support using the 's' selector for changing text surroundings
  use { "tpope/vim-surround", commit = "3d188ed2113431cf8dac77be61b842acb64433d9" }
  use {
    "phaazon/hop.nvim", branch = "v2", commit = "90db1b2c61b820e230599a04fedcd2679e64bd07" }
  -- use 'ggandor/lightspeed.nvim'
  -- use{ "ggandor/leap.nvim", commit = "f7391b5fe9771d788816383ee3c75e0be92022af" }

  -- debugging
  use { "mfussenegger/nvim-dap",commit = "56118cee6af15cb9ddba9d080880949d8eeb0c9f" }
  use {
    "rcarriga/nvim-dap-ui",requires = { "mfussenegger/nvim-dap" },commit = "4ce7b97dd8f50b4f672948a34bf8f3a56214fdb8" }
  use { "jayp0521/mason-nvim-dap.nvim",commit = "c836e511e796d2b6a25ad9f164f5b25d8b9ff705" }
  use {
    "nvim-neotest/neotest",requires = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "antoinemadec/FixCursorHold.nvim",
  },commit = "6435a367a57f267039c4c69a723cec09ae61b17e" }
  use { "nvim-neotest/neotest-python", commit = "6c06041cfb45f45e276068020baa06c06fe20d5c" }
  use { "rouge8/neotest-rust",commit = "eaaf57c2124067167b6f7dcab6feedfcabd27fbb" }
  -- use 'mfussenegger/nvim-dap-python'
  -- use 'ChristianChiarulli/neovim-codicons'

  -- helm syntax highlighting
  use { "towolf/vim-helm", commit = "c2e7b85711d410e1d73e64eb5df7b70b1c4c10eb" }
  -- use 'mortepau/codicons.nvim'

  -- hex colors to actual colors (for css)
  use { "norcalli/nvim-colorizer.lua", commit = "36c610a9717cc9ec426a07c8e6bf3b3abcb139d6" }

  -- Install neoscopes.
  use { "smartpde/neoscopes",commit = "88ca15efcc20b267789d74ca483cc8bac85b3083" }
  -- use { "napisani/neoscopes" }
  -- use('/Users/nick/code/neoscopes')
  -- use('/Users/nick/code/nvim-github-codesearch')
  use { 'napisani/nvim-github-codesearch', run = 'nix-shell make' }
  -- use {'napisani/nvim-search-rules' }

  -- use { '/Users/nick/code/nvim-search-rules' }

  -- copilot
  use { "github/copilot.vim",commit = "1358e8e45ecedc53daf971924a0541ddf6224faf" }

  use { 'karb94/neoscroll.nvim', commit = "d7601c26c8a183fa8994ed339e70c2d841253e93" }
  use { 'hkupty/iron.nvim', commit = "792dd11752c4699ea52c737b5e932d6f21b25834" }
  use({
      "jackMort/ChatGPT.nvim",
      requires = {
        "MunifTanjim/nui.nvim", 
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim"
      }
  })
  use ({
  "kndndrj/nvim-dbee",
    -- "/Users/nick/code/nvim-dbee",
  requires = {
    "MunifTanjim/nui.nvim",
  },
  run = function()
    -- Install tries to automatically detect the install method.
    -- if it fails, try calling it with one of these parameters:
    --    "curl", "wget", "bitsadmin", "go"
    require("dbee").install()
  end,
})
  -- use 'direnv/direnv.vim'
  -- use('/Users/nick/code/monoscope')
  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end

-- Install your plugins here
return packer.startup(define_plugins)
