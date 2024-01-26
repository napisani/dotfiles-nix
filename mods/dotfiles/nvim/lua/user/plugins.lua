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
  use { "nvim-lua/plenary.nvim",commit = "55d9fe89e33efd26f532ef20223e5f9430c8b0c0" }

  -- Autopairs, integrates with both cmp and treesitter
  use { "windwp/nvim-autopairs",commit = "9fd41181693dd4106b3e414a822bb6569924de81" }

  use { "tpope/vim-commentary",commit = "f67e3e67ea516755005e6cccb178bc8439c6d402" }
  use { "JoosepAlviste/nvim-ts-context-commentstring",commit = "1277b4a1f451b0f18c0790e1a7f12e1e5fdebfee" }
  use { "kyazdani42/nvim-web-devicons",commit = "140edfcf25093e8b321d13e154cbce89ee868ca0" }
  use { "kyazdani42/nvim-tree.lua",commit = "e9c5abe073a973f54d3ca10bfe30f253569f4405" }
  use { "akinsho/bufferline.nvim",commit = "e48ce1805697e4bb97bc171c081e849a65859244" }
  use { "moll/vim-bbye", commit = "25ef93ac5a87526111f43e5110675032dbcacf56" }
  use { "nvim-lualine/lualine.nvim",commit = "566b7036f717f3d676362742630518a47f132fff" }

  use { "ahmedkhalf/project.nvim", commit = "8c6bad7d22eef1b71144b401c9f74ed01526a4fb" }
  use { "lewis6991/impatient.nvim", commit = "47302af74be7b79f002773011f0d8e85679a7618" }
  use { "lukas-reineke/indent-blankline.nvim",commit = "3c8a185da4b8ab7aef487219f5e001b11d4b6aaf" }

  use { "goolord/alpha-nvim",commit = "4b36c1ca9ea475bdc006896657cf1ccc486aeffa" }
  use { "folke/which-key.nvim" }

  -- Colorschemes
  -- use { "folke/tokyonight.nvim",commit = "9a01eada39558dc3243278e6805d90e8dff45dc0" }
  -- use { "morhetz/gruvbox",commit = "f1ecde848f0cdba877acb0c740320568252cc482" }
  -- use { "shaunsingh/nord.nvim",commit = "15fbfc38a83980b93e169b32a1bf64757f1e2bf4" }
  use { "rebelot/kanagawa.nvim", commit = "c19b9023842697ec92caf72cd3599f7dd7be4456" }

  -- Cmp
  -- The completion plugin
  use { "hrsh7th/nvim-cmp",commit = "538e37ba87284942c1d76ed38dd497e54e65b891" }
  -- buffer completions
  use { "hrsh7th/cmp-buffer", commit = "3022dbc9166796b644a841a02de8dd1cc1d311fa" }
  -- path completions
  use { "hrsh7th/cmp-path", commit = "91ff86cd9c29299a64f968ebb45846c485725f23" }
  -- snippet completions
  use { "saadparwaiz1/cmp_luasnip", commit = "05a9ab28b53f71d1aece421ef32fee2cb857a843" }
  use { "hrsh7th/cmp-nvim-lsp",commit = "5af77f54de1b16c34b23cba810150689a3a90312" }
  use { "hrsh7th/cmp-nvim-lua", commit = "f12408bdb54c39c23e67cab726264c10db33ada8" }
  --use { "hrsh7th/cmp-nvim-lsp-signature-help" }
  use { "erhickey/sig-window-nvim", commit = "606e9dbd1f80646c8d2d1b4384872ec718ddc48a" }

  -- Snippets
  --snippet engine
  use { "L3MON4D3/LuaSnip",commit = "2dbef19461198630b3d7c39f414d09fb07d1fdd2" }
  -- a bunch of snippets to use
  use { "rafamadriz/friendly-snippets",commit = "69a2c1675b66e002799f5eef803b87a12f593049" }

  -- LSP
  use { "neovim/nvim-lspconfig",commit = "042aa6b27b8b8d4f4e1bd42de2037c83d676a8a0" }
  -- simple to use language server installer
  use { "williamboman/mason.nvim",
    run = ":MasonUpdate" -- :MasonUpdate updates registry contents
  }
  use { "williamboman/mason-lspconfig.nvim",commit = "3ba1b92b771f33256b4969d696b82c8ae7075364" }
  -- for formatters and linters
  use { "jose-elias-alvarez/null-ls.nvim", commit = "0010ea927ab7c09ef0ce9bf28c2b573fc302f5a7" }
  use { "RRethy/vim-illuminate", commit = "3bd2ab64b5d63b29e05691e624927e5ebbf0fb86" }
  use {
    'creativenull/efmls-configs-nvim',tag = 'v1.*',requires = { 'neovim/nvim-lspconfig' },commit = "5372981bc8785facefb51cd50cb0888d1129a291"
  }

  -- Telescope
  use { "nvim-telescope/telescope.nvim",commit = "24778fd72fcf39a0b1a6f7c6f4c4e01fef6359a2" }
  use { "nvim-telescope/telescope-file-browser.nvim",commit = "6f735a63dc24b9aed527cd505a31864223c8a6d8" }
  use {
    "benfowler/telescope-luasnip.nvim", commit = "2ef7da3a363890686dbaad18ddbf59177cfe4f78"
  }

  -- Treesitter
  use {
    "nvim-treesitter/nvim-treesitter",commit = "64b3d5e5698d485a4f197ffbe85a4b6c29e16325" }

  -- Git
  use { "lewis6991/gitsigns.nvim" }
  use { "tpope/vim-fugitive",commit = "854a8df0d06b8d3fcb30fa7f2b08c62b553eee3b" }
  use {
    "sindrets/diffview.nvim", requires = "nvim-lua/plenary.nvim", commit = "3dc498c9777fe79156f3d32dddd483b8b3dbd95f" }

  -- vim.notify notifications
  use { "rcarriga/nvim-notify",commit = "80b67b265530632505193553d05127ae7fe09ddd" }

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
    "phaazon/hop.nvim", branch = "v2", commit = "90db1b2c61b820e230599a04fedcd2679e64bd07" }
  -- use 'ggandor/lightspeed.nvim'
  -- use{ "ggandor/leap.nvim", commit = "f7391b5fe9771d788816383ee3c75e0be92022af" }

  -- debugging
  use { "mfussenegger/nvim-dap",commit = "9adbfdca13afbe646d09a8d7a86d5d031fb9c5a5" }
  use {
    "rcarriga/nvim-dap-ui",requires = { "mfussenegger/nvim-dap" },commit = "a6beb3a855b42faa1d0fee1081602257719c2c5e" }
  use { "jayp0521/mason-nvim-dap.nvim",commit = "3614a39aae98ccd34124b072939d6283853b3dd2" }
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
  use { "norcalli/nvim-colorizer.lua", commit = "36c610a9717cc9ec426a07c8e6bf3b3abcb139d6" }

  -- Install neoscopes.
  use { "smartpde/neoscopes", commit = "470dff042004b93c10d262e8b0ad7bf6f703f86f" }

  -- use { "napisani/neoscopes" }
  -- use('/Users/nick/code/neoscopes')
  -- use('/Users/nick/code/nvim-github-codesearch')
  use { 'napisani/nvim-github-codesearch', run = 'nix-shell make' }

  -- use {'napisani/nvim-search-rules' }
  -- use { '/Users/nick/code/nvim-search-rules' }

  -- copilot
  use { "github/copilot.vim",commit = "49e0348bfb913fae63ca5ddb987a8bccd193da86" }

  use { 'karb94/neoscroll.nvim',commit = "be4ebf855a52f71ca4338694a5696675d807eff9" }
  use { 'hkupty/iron.nvim', commit = "7f876ee3e1f4ea1e5284b1b697cdad5b256e8046" }

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
    'glacambre/firenvim',run = function() vim.fn['firenvim#install'](0) end
,commit = "471354b1721d7082ffc3468dc84578e6ee42f163" }

  use {
    "pmizio/typescript-tools.nvim",requires = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },commit =
  "c43d9580c3ff5999a1eabca849f807ab33787ea7"
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
    "alexghergh/nvim-tmux-navigation", commit = "d9efffa413a530bdea3783af4fea86be84940283" }

  -- use('/Users/nick/code/monoscope')
  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end

-- Install your plugins here
return packer.startup(define_plugins)
