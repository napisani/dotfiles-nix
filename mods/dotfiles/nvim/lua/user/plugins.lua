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
  use { "nvim-lua/plenary.nvim",commit = "36aaceb6e93addd20b1b18f94d86aecc552f30c4" }

  -- Autopairs, integrates with both cmp and treesitter
  use { "windwp/nvim-autopairs",commit = "41803bdbf75569571f93fd4571f6c654635b1b46" }

  use { "tpope/vim-commentary", commit = "e87cd90dc09c2a203e13af9704bd0ef79303d755" }
  use { "JoosepAlviste/nvim-ts-context-commentstring",commit = "0bf8fbc2ca8f8cdb6efbd0a9e32740d7a991e4c3" }
  use { "kyazdani42/nvim-web-devicons",commit = "2a125024a137677930efcfdf720f205504c97268" }
  use { "kyazdani42/nvim-tree.lua",commit = "f873625d0636889af4cd47a01e486beb865db205" }
  use { "akinsho/bufferline.nvim",commit = "02d795081e6a24ec1fd506c513491543793d0780" }
  use { "moll/vim-bbye", commit = "25ef93ac5a87526111f43e5110675032dbcacf56" }
  use { "nvim-lualine/lualine.nvim",commit = "05d78e9fd0cdfb4545974a5aa14b1be95a86e9c9" }

  use { "ahmedkhalf/project.nvim",commit = "8c6bad7d22eef1b71144b401c9f74ed01526a4fb" }
  use { "lewis6991/impatient.nvim",commit = "47302af74be7b79f002773011f0d8e85679a7618" }
  use { "lukas-reineke/indent-blankline.nvim",commit = "7075d7861f7a6bbf0de0298c83f8a13195e6ec01" }
  use { "goolord/alpha-nvim",commit = "9e33db324b8bb7a147bce9ea5496686ee859461d" }
  use { "folke/which-key.nvim" }

  -- Colorschemes
  use { "folke/tokyonight.nvim",commit = "161114bd39b990995e08dbf941f6821afbdcd666" }
  use { "lunarvim/darkplus.nvim",commit = "7c236649f0617809db05cd30fb10fed7fb01b83b" }
  use { "morhetz/gruvbox", commit = "bf2885a95efdad7bd5e4794dd0213917770d79b7" }
  use { "shaunsingh/nord.nvim",commit = "fab04b2dd4b64f4b1763b9250a8824d0b5194b8f" }
  -- " intellj idea darcula-solid
  use { "doums/darcula", commit = "faf8dbab27bee0f27e4f1c3ca7e9695af9b1242b" }
  use { "briones-gabriel/darcula-solid.nvim", commit = "d950b9ca20096313c435a93e57af7815766f3d3d" }
  use { "rebelot/kanagawa.nvim",commit = "14a7524a8b259296713d4d77ef3c7f4dec501269" }

  -- Cmp
  -- The completion plugin
  use { "hrsh7th/nvim-cmp",commit = "b8c2a62b3bd3827aa059b43be3dd4b5c45037d65" }
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
  use { "L3MON4D3/LuaSnip",commit = "a13af80734eb28f744de6c875330c9d3c24b5f3b" }
  -- a bunch of snippets to use
  use { "rafamadriz/friendly-snippets",commit = "49ca2a0e0e26427b550b1f64272d7fe7e4d7d51b" }

  -- LSP
  use { "neovim/nvim-lspconfig",commit = "fefba589c56a5568a089299e36a4c8242502faaa" }
  -- simple to use language server installer
  use { "williamboman/mason.nvim",
    run = ":MasonUpdate" -- :MasonUpdate updates registry contents
  }
  use { "williamboman/mason-lspconfig.nvim",commit = "d381fcb78d7a562c3244e1c8f76406954649db36" }
  -- for formatters and linters
  use { "jose-elias-alvarez/null-ls.nvim",commit = "a138b14099e9623832027ea12b4631ddd2a49256" }
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
    "nvim-treesitter/nvim-treesitter",commit = "150be01d47579ba70137813348a2f0a5be7a7866" }

  -- Git
  use { "lewis6991/gitsigns.nvim"  }
  use { "tpope/vim-fugitive",commit = "43f18ab9155c853a84ded560c6104e6300ad41da" }
  -- use { 'idanarye/vim-merginal' }
  use {
    "sindrets/diffview.nvim",requires = "nvim-lua/plenary.nvim",commit = "0ad3e4f834093412ebbf317b7eaa9c59568824b9" }

  -- vim.notify notifications
  use { "rcarriga/nvim-notify",commit = "ea9c8ce7a37f2238f934e087c255758659948e0f" }

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
  use { "mfussenegger/nvim-dap",commit = "7c1d47cf7188fc31acdf951f9eee22da9d479152" }
  use {
    "rcarriga/nvim-dap-ui",requires = { "mfussenegger/nvim-dap" },commit = "c020f660b02772f9f3d11f599fefad3268628a9e" }
  use { "jayp0521/mason-nvim-dap.nvim",commit = "e4d56b400e9757b1dc77d620fd3069396e92d5fc" }
  use {
    "nvim-neotest/neotest",requires = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "antoinemadec/FixCursorHold.nvim",
  },commit = "0207e4025e5558fdd0b3951f250689eede5c75b2" }
  use { "nvim-neotest/neotest-python", commit = "6c06041cfb45f45e276068020baa06c06fe20d5c" }
  use { "rouge8/neotest-rust",commit = "cc1821d580e8ee36bdd13d67b3291b8cd1792ec9" }
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
  use { 'hkupty/iron.nvim',commit = "9017061849e543d8e94b79d2a94b95e856ab6a10" }
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
