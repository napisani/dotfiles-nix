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
  use { "nvim-lua/plenary.nvim", commit = "253d34830709d690f013daf2853a9d21ad7accab" }

  -- Autopairs, integrates with both cmp and treesitter
  use { "windwp/nvim-autopairs", commit = "e755f366721bc9e189ddecd39554559045ac0a18" }

  use { "tpope/vim-commentary", commit = "e87cd90dc09c2a203e13af9704bd0ef79303d755" }
  use { "JoosepAlviste/nvim-ts-context-commentstring", commit = "729d83ecb990dc2b30272833c213cc6d49ed5214" }
  use { "kyazdani42/nvim-web-devicons", commit = "95b1e300699be8eb6b5be1758a9d4d69fe93cc7f" }
  use { "kyazdani42/nvim-tree.lua", commit = "aa9971768a08caa4f10f94ab84e48d2ceb30b1c0" }
  use { "akinsho/bufferline.nvim", commit = "3677aceb9a72630b0613e56516c8f7151b86f95c" }
  use { "moll/vim-bbye", commit = "25ef93ac5a87526111f43e5110675032dbcacf56" }
  use { "nvim-lualine/lualine.nvim", commit = "e99d733e0213ceb8f548ae6551b04ae32e590c80" }

  use { "ahmedkhalf/project.nvim", commit = "1c2e9c93c7c85126c2197f5e770054f53b1926fb" }
  use { "lewis6991/impatient.nvim", commit = "c90e273f7b8c50a02f956c24ce4804a47f18162e" }
  use { "lukas-reineke/indent-blankline.nvim", commit = "018bd04d80c9a73d399c1061fa0c3b14a7614399" }
  use { "goolord/alpha-nvim", commit = "dafa11a6218c2296df044e00f88d9187222ba6b0" }
  use { "folke/which-key.nvim" }

  -- Colorschemes
  use { "folke/tokyonight.nvim", commit = "edffa82026914be54c8220973b0385f61d3392f0" }
  use { "lunarvim/darkplus.nvim", commit = "1826879d9cb14e5d93cd142d19f02b23840408a6" }
  use { "morhetz/gruvbox", commit = "bf2885a95efdad7bd5e4794dd0213917770d79b7" }
  use { "shaunsingh/nord.nvim", commit = "be318c83a233cb877ba08faa15380a54241272b1" }
  -- " intellj idea darcula-solid
  use { "doums/darcula", commit = "faf8dbab27bee0f27e4f1c3ca7e9695af9b1242b" }
  use { "briones-gabriel/darcula-solid.nvim", commit = "d950b9ca20096313c435a93e57af7815766f3d3d" }
  use { "rebelot/kanagawa.nvim", commit = "d8800c36a7f3bcec953288926b00381c028ed97f" }

  -- Cmp
  -- The completion plugin
  use { "hrsh7th/nvim-cmp", commit = "777450fd0ae289463a14481673e26246b5e38bf2" }
  -- buffer completions
  use { "hrsh7th/cmp-buffer", commit = "3022dbc9166796b644a841a02de8dd1cc1d311fa" }
  -- path completions
  use { "hrsh7th/cmp-path", commit = "91ff86cd9c29299a64f968ebb45846c485725f23" }
  -- snippet completions
  use { "saadparwaiz1/cmp_luasnip", commit = "18095520391186d634a0045dacaa346291096566" }
  use { "hrsh7th/cmp-nvim-lsp", commit = "0e6b2ed705ddcff9738ec4ea838141654f12eeef" }
  use { "hrsh7th/cmp-nvim-lua", commit = "f3491638d123cfd2c8048aefaf66d246ff250ca6" }
  --use { "hrsh7th/cmp-nvim-lsp-signature-help" }
  use { "erhickey/sig-window-nvim", commit = "e2984f7c95ebc38fe43635d3951f40a29a79b069" }

  -- Snippets
  --snippet engine
  use { "L3MON4D3/LuaSnip", commit = "025886915e7a1442019f467e0ae2847a7cf6bf1a" }
  -- a bunch of snippets to use
  use { "rafamadriz/friendly-snippets", commit = "25ddcd96540a2ce41d714bd7fea2e7f75fea8ead" }

  -- LSP
  use { "neovim/nvim-lspconfig", commit = "0f94c5fded29c0024254259f3d8a0284bfb507ea" }
  -- simple to use language server installer
  use { "williamboman/mason.nvim",
    run = ":MasonUpdate" -- :MasonUpdate updates registry contents
  }
  use { "williamboman/mason-lspconfig.nvim", commit = "2b811031febe5f743e07305738181ff367e1e452" }
  -- for formatters and linters
  use { "jose-elias-alvarez/null-ls.nvim", commit = "13dd1fc13063681ca7e039436c88f6eca7e3e937" }
  use { "RRethy/vim-illuminate", commit = "a2907275a6899c570d16e95b9db5fd921c167502" }

  -- Telescope
  use { "nvim-telescope/telescope.nvim", commit = "942fe5faef47b21241e970551eba407bc10d9547" }
  use { "nvim-telescope/telescope-file-browser.nvim", commit = "61b3769065131129716974f7fb63f82ee409bd80" }
  use {
    "benfowler/telescope-luasnip.nvim",
    commit = "849c4ee1951f34041a26744d2a88284545564ff0"
  }

  -- Treesitter
  use {
    "nvim-treesitter/nvim-treesitter", commit = "87cf2abeb6077ac19a1249d0b06f223aa398a0a0" }

  -- Git
  use { "lewis6991/gitsigns.nvim", commit = "ca473e28382f1524aa3d2b6f04bcf54f2e6a64cb" }
  use { "tpope/vim-fugitive", commit = "8ad2b96cdfda11070645f71b2d804466b750041d" }
  -- use { 'idanarye/vim-merginal' }
  use {
    "sindrets/diffview.nvim", requires = "nvim-lua/plenary.nvim", commit = "58035354fc79c6ec42fa7b218dab90bd3968615f" }

  -- vim.notify notifications
  use { "rcarriga/nvim-notify", commit = "50d037041ada0895aeba4c0215cde6d11b7729c4" }

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
  use { "mfussenegger/nvim-dap", commit = "7e81998e31277c7a33b6c34423640900c5c2c776" }
  use {
    "rcarriga/nvim-dap-ui", requires = { "mfussenegger/nvim-dap" }, commit = "bdb94e3853d11b5ce98ec182e5a3719d5c0ef6fd" }
  use { "jayp0521/mason-nvim-dap.nvim", commit = "8c5d0212bb385ce363ac3a00aa2e16d88ac44ba7" }
  use {
    "nvim-neotest/neotest", requires = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "antoinemadec/FixCursorHold.nvim",
  }, commit = "bbbfa55d850f1aaa6707ea85fb5230ac866459c6" }
  use { "nvim-neotest/neotest-python", commit = "6c06041cfb45f45e276068020baa06c06fe20d5c" }
  use { "rouge8/neotest-rust", commit = "11ae2469d2a43436b81577c5ad3137ee3c75ff6c" }
  -- use 'mfussenegger/nvim-dap-python'
  -- use 'ChristianChiarulli/neovim-codicons'
  -- use 'puremourning/vimspector'

  -- helm syntax highlighting
  use { "towolf/vim-helm", commit = "c2e7b85711d410e1d73e64eb5df7b70b1c4c10eb" }
  -- use 'mortepau/codicons.nvim'

  -- hex colors to actual colors (for css)
  use { "norcalli/nvim-colorizer.lua", commit = "36c610a9717cc9ec426a07c8e6bf3b3abcb139d6" }

  -- Install neoscopes.
  use { "smartpde/neoscopes", commit = "c05157d47231d0a44798526758f26729a19a5bfd" }
  -- use { "napisani/neoscopes" }
  -- use('/Users/nick/code/neoscopes')
  -- use('/Users/nick/code/nvim-github-codesearch')
  use { 'napisani/nvim-github-codesearch', run = 'make' }
  -- use {'napisani/nvim-search-rules' }

  -- use { '/Users/nick/code/nvim-search-rules' }

  -- copilot
  use { "github/copilot.vim", commit = "9e869d29e62e36b7eb6fb238a4ca6a6237e7d78b" }

  use { 'karb94/neoscroll.nvim', commit = "d7601c26c8a183fa8994ed339e70c2d841253e93" }
  use { 'hkupty/iron.nvim', commit = "792dd11752c4699ea52c737b5e932d6f21b25834" }
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
