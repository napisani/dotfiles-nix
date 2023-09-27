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
  use { "wbthomason/packer.nvim",commit = "ea0cc3c59f67c440c5ff0bbe4fb9420f4350b9a3" }

  -- Useful lua functions used by lots of plugins
  use { "nvim-lua/plenary.nvim",commit = "9ce85b0f7dcfe5358c0be937ad23e456907d410b" }

  -- Autopairs, integrates with both cmp and treesitter
  use { "windwp/nvim-autopairs",commit = "de4f7138a68d5d5063170f2182fd27faf06b0b54" }

  use { "tpope/vim-commentary", commit = "e87cd90dc09c2a203e13af9704bd0ef79303d755" }
  use { "JoosepAlviste/nvim-ts-context-commentstring",commit = "95e9ba9de4289d221666b66fd930d157c7ca08c6" }
  use { "kyazdani42/nvim-web-devicons",commit = "45d0237c427baba8cd05e0ab26d30e2ee58c2c82" }
  use { "kyazdani42/nvim-tree.lua",commit = "934469b9b6df369e198fb3016969e56393b0dc07" }
  use { "akinsho/bufferline.nvim",commit = "6ecd37e0fa8b156099daedd2191130e083fb1490" }
  use { "moll/vim-bbye", commit = "25ef93ac5a87526111f43e5110675032dbcacf56" }
  use { "nvim-lualine/lualine.nvim",commit = "45e27ca739c7be6c49e5496d14fcf45a303c3a63" }

  use { "ahmedkhalf/project.nvim",commit = "8c6bad7d22eef1b71144b401c9f74ed01526a4fb" }
  use { "lewis6991/impatient.nvim",commit = "47302af74be7b79f002773011f0d8e85679a7618" }
  use { "lukas-reineke/indent-blankline.nvim",commit = "9637670896b68805430e2f72cf5d16be5b97a22a" }
  use { "goolord/alpha-nvim",commit = "234822140b265ec4ba3203e3e0be0e0bb826dff5" }
  use { "folke/which-key.nvim" }

  -- Colorschemes
  -- use { "folke/tokyonight.nvim",commit = "9a01eada39558dc3243278e6805d90e8dff45dc0" }
  -- use { "lunarvim/darkplus.nvim",commit = "7c236649f0617809db05cd30fb10fed7fb01b83b" }
  -- use { "morhetz/gruvbox",commit = "f1ecde848f0cdba877acb0c740320568252cc482" }
  -- use { "shaunsingh/nord.nvim",commit = "15fbfc38a83980b93e169b32a1bf64757f1e2bf4" }
  -- " intellj idea darcula-solid
  -- use { "doums/darcula", commit = "faf8dbab27bee0f27e4f1c3ca7e9695af9b1242b" }
  -- use { "briones-gabriel/darcula-solid.nvim", commit = "d950b9ca20096313c435a93e57af7815766f3d3d" }
  use { "rebelot/kanagawa.nvim",commit = "a4e99f089110c6d00bc33f5497709200e914e763" }

  -- Cmp
  -- The completion plugin
  use { "hrsh7th/nvim-cmp",commit = "5dce1b778b85c717f6614e3f4da45e9f19f54435" }
  -- buffer completions
  use { "hrsh7th/cmp-buffer", commit = "3022dbc9166796b644a841a02de8dd1cc1d311fa" }
  -- path completions
  use { "hrsh7th/cmp-path", commit = "91ff86cd9c29299a64f968ebb45846c485725f23" }
  -- snippet completions
  use { "saadparwaiz1/cmp_luasnip", commit = "18095520391186d634a0045dacaa346291096566" }
  use { "hrsh7th/cmp-nvim-lsp",commit = "44b16d11215dce86f253ce0c30949813c0a90765" }
  use { "hrsh7th/cmp-nvim-lua",commit = "f12408bdb54c39c23e67cab726264c10db33ada8" }
  --use { "hrsh7th/cmp-nvim-lsp-signature-help" }
  use { "erhickey/sig-window-nvim",commit = "606e9dbd1f80646c8d2d1b4384872ec718ddc48a" }

  -- Snippets
  --snippet engine
  use { "L3MON4D3/LuaSnip",commit = "480b032f6708573334f4437d3f83307d143f1a72" }
  -- a bunch of snippets to use
  use { "rafamadriz/friendly-snippets",commit = "ebf6d6e83494cdd88a54a429340256f4dbb6a052" }

  -- LSP
  use { "neovim/nvim-lspconfig",commit = "bfdf2e91e7297a54bcc09d3e092a12bff69a1cf4" }
  -- simple to use language server installer
  use { "williamboman/mason.nvim",
    run = ":MasonUpdate" -- :MasonUpdate updates registry contents
  }
  use { "williamboman/mason-lspconfig.nvim",commit = "2451adb9bdb0fd32140bf3aa8dbc17ff60050db3" }
  -- for formatters and linters
  use { "jose-elias-alvarez/null-ls.nvim",commit = "0010ea927ab7c09ef0ce9bf28c2b573fc302f5a7" }
  use { "RRethy/vim-illuminate",commit = "1b5d70332a51a1de05f281069851865a2bb1e6d7" }

  -- Telescope
  use { "nvim-telescope/telescope.nvim",commit = "ed9574dd6dde143d009b2528ea6d79bd34bbe6c8" }
  use { "nvim-telescope/telescope-file-browser.nvim",commit = "6e51d0cd6447cf2525412220ff0a2885eef9039c" }
  use {
    "benfowler/telescope-luasnip.nvim",
    commit = "849c4ee1951f34041a26744d2a88284545564ff0"
  }

  -- Treesitter
  use {
    "nvim-treesitter/nvim-treesitter",commit = "b5873bacb4ce44e0aac313abb28bb72e67fc9a53" }

  -- Git
  use { "lewis6991/gitsigns.nvim"  }
  use { "tpope/vim-fugitive",commit = "99db68d9b3304580bd383da7aaee05c7a954a344" }
  -- use { 'idanarye/vim-merginal' }
  use {
    "sindrets/diffview.nvim",requires = "nvim-lua/plenary.nvim",commit = "a111d19ccceac6530448d329c63f998f77b5626e" }

  -- vim.notify notifications
  use { "rcarriga/nvim-notify",commit = "94859430020f5cf32a1b97ddd9e596fed9db7981" }

  -- Rust tools
  use { "simrat39/rust-tools.nvim",commit = "0cc8adab23117783a0292a0c8a2fbed1005dc645" }

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
  use { "mfussenegger/nvim-dap",commit = "b3d4408e29d924fe130c9397a7c3b3630b3ea671" }
  use {
    "rcarriga/nvim-dap-ui",requires = { "mfussenegger/nvim-dap" },commit = "34160a7ce6072ef332f350ae1d4a6a501daf0159" }
  use { "jayp0521/mason-nvim-dap.nvim",commit = "6148b51db945b55b3b725da39eaea6441e59dff8" }
  use {
    "nvim-neotest/neotest",requires = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "antoinemadec/FixCursorHold.nvim",
  },commit = "1e67a504d03def3a6a1125d934cb511680f72555" }
  use { "nvim-neotest/neotest-python",commit = "81d2265efac717bb567bc15cc652ae10801286b3" }
  use { "rouge8/neotest-rust",commit = "139cff7c85598ec591b5ed7d71ce8ed3b5313b97" }
  -- use 'mfussenegger/nvim-dap-python'
  -- use 'ChristianChiarulli/neovim-codicons'

  -- helm syntax highlighting
  use { "towolf/vim-helm", commit = "c2e7b85711d410e1d73e64eb5df7b70b1c4c10eb" }
  -- use 'mortepau/codicons.nvim'

  -- hex colors to actual colors (for css)
  use { "norcalli/nvim-colorizer.lua", commit = "36c610a9717cc9ec426a07c8e6bf3b3abcb139d6" }

  -- Install neoscopes.
  use { "smartpde/neoscopes",commit = "d3f92e9360da7b7ab4eb6c5811d5ebaf7135239f" }
  -- use { "napisani/neoscopes" }
  -- use('/Users/nick/code/neoscopes')
  -- use('/Users/nick/code/nvim-github-codesearch')
  use { 'napisani/nvim-github-codesearch', run = 'nix-shell make' }
  -- use {'napisani/nvim-search-rules' }

  -- use { '/Users/nick/code/nvim-search-rules' }

  -- copilot
  use { "github/copilot.vim",commit = "998cf5ab1b85e844c7e8edb864a997e590df7182" }

  use { 'karb94/neoscroll.nvim',commit = "4bc0212e9f2a7bc7fe7a6bceb15b33e39f0f41fb" }
  use { 'hkupty/iron.nvim',commit = "7f876ee3e1f4ea1e5284b1b697cdad5b256e8046" }

  -- use({
  --     "jackMort/ChatGPT.nvim",
  --     requires = {
  --       "MunifTanjim/nui.nvim", 
  --       "nvim-lua/plenary.nvim",
  --       "nvim-telescope/telescope.nvim"
  --     }
  -- })

  use({ "robitx/gp.nvim", commit="5ec4ff704838ea214c53b0269d31f82b4ea0bee4" })

  -- use({
  --    "dpayne/CodeGPT.nvim",
  --    requires = {
  --       "MunifTanjim/nui.nvim",
  --       "nvim-lua/plenary.nvim",
  --    },
  --    config = function()
  --       require("codegpt.config")
  --    end
  -- })
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
      'glacambre/firenvim',      run = function() vim.fn['firenvim#install'](0) end
,      commit = "138424db463e6c0e862a05166a4ccc781cd7c19d"  }

  use {
    "pmizio/typescript-tools.nvim",requires = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },commit = "f7c45763fe1513e257ebf45bedfc5e6dd1aade78"
    -- config = function()
    --   require("typescript-tools").setup {}
    -- end,
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
    "alexghergh/nvim-tmux-navigation",
    commit = "543f090a45cef28156162883d2412fffecb6b750",
  }
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
