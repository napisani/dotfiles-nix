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
  use { "nvim-lua/plenary.nvim",commit = "4f71c0c4a196ceb656c824a70792f3df3ce6bb6d" }

  -- Autopairs, integrates with both cmp and treesitter
  use { "windwp/nvim-autopairs",commit = "90f824d37c0cb079d2764927e73af77faa9ba0ef" }

  use { "tpope/vim-commentary",commit = "f67e3e67ea516755005e6cccb178bc8439c6d402" }
  use { "JoosepAlviste/nvim-ts-context-commentstring",commit = "7ab799a9792f7cf3883cf28c6a00ad431f3d382a" }
  use { "kyazdani42/nvim-web-devicons",commit = "14ac5887110b06b89a96881d534230dac3ed134d" }
  use { "kyazdani42/nvim-tree.lua",commit = "d35a8d5ec6358ada4b058431b367b32360737466" }
  use { "akinsho/bufferline.nvim",commit = "b15c6daf5a64426c69732b31a951f4e438cb6590" }
  use { "moll/vim-bbye", commit = "25ef93ac5a87526111f43e5110675032dbcacf56" }
  use { "nvim-lualine/lualine.nvim",commit = "7d131a8d3ba5016229e8a1d08bf8782acea98852" }

  use { "ahmedkhalf/project.nvim", commit = "8c6bad7d22eef1b71144b401c9f74ed01526a4fb" }
  use { "lewis6991/impatient.nvim", commit = "47302af74be7b79f002773011f0d8e85679a7618" }
  use { "lukas-reineke/indent-blankline.nvim",commit = "821a7acd88587d966f7e464b0b3031dfe7f5680c" }

  use { "goolord/alpha-nvim",commit = "1356b9ef31b985d541d94314f2cf73c61124bf1d" }
  use { "folke/which-key.nvim" }

  -- Colorschemes
  -- use { "folke/tokyonight.nvim",commit = "9a01eada39558dc3243278e6805d90e8dff45dc0" }
  -- use { "morhetz/gruvbox",commit = "f1ecde848f0cdba877acb0c740320568252cc482" }
  -- use { "shaunsingh/nord.nvim",commit = "15fbfc38a83980b93e169b32a1bf64757f1e2bf4" }
  use { "rebelot/kanagawa.nvim",commit = "ab41956c4559c3eb21e713fcdf54cda1cb6d5f40" }

  -- Cmp
  -- The completion plugin
  use { "hrsh7th/nvim-cmp",commit = "04e0ca376d6abdbfc8b52180f8ea236cbfddf782" }
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
  use { "L3MON4D3/LuaSnip",commit = "f3b3d3446bcbfa62d638b1903ff00a78b2b730a1" }
  -- a bunch of snippets to use
  use { "rafamadriz/friendly-snippets",commit = "dbd45e9ba76d535e4cba88afa1b7aa43bb765336" }

  -- LSP
  use { "neovim/nvim-lspconfig",commit = "d1bab4cf4b69e49d6058028fd933d8ef5e74e680" }
  -- simple to use language server installer
  use { "williamboman/mason.nvim",
    run = ":MasonUpdate" -- :MasonUpdate updates registry contents
  }
  use { "williamboman/mason-lspconfig.nvim",commit = "fe4cce44dec93c69be17dad79b21de867dde118a" }
  -- for formatters and linters
  use { "jose-elias-alvarez/null-ls.nvim", commit = "0010ea927ab7c09ef0ce9bf28c2b573fc302f5a7" }
  use { "RRethy/vim-illuminate",commit = "305bf07b919ac526deb5193280379e2f8b599926" }
  use {
    'creativenull/efmls-configs-nvim',tag = 'v1.*',requires = { 'neovim/nvim-lspconfig' },commit = "a61c52d325835e24dc14ffb7748a32b8f087ae32"
  }

  -- Telescope
  use { "nvim-telescope/telescope.nvim",commit = "b744cf59752aaa01561afb4223006de26f3836fd" }
  use { "nvim-telescope/telescope-file-browser.nvim",commit = "48ffb8de688a22942940f50411d5928631368848" }
  use {
    "benfowler/telescope-luasnip.nvim", commit = "2ef7da3a363890686dbaad18ddbf59177cfe4f78"
  }

  -- Treesitter
  use {
    "nvim-treesitter/nvim-treesitter",commit = "4b27f87fef2df2feaca47a8498f5f7f51e94b765" }

  -- Git
  use { "lewis6991/gitsigns.nvim" }
  use { "tpope/vim-fugitive",commit = "011cf4fcb93a9649ffc6dcdff56ef948f5d0f7cc" }
  use {
    "sindrets/diffview.nvim", requires = "nvim-lua/plenary.nvim", commit = "3dc498c9777fe79156f3d32dddd483b8b3dbd95f" }

  -- vim.notify notifications
  use { "rcarriga/nvim-notify",commit = "5371f4bfc1f6d3adf4fe9d62cd3a9d44356bfd15" }

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
  use{ "mfussenegger/nvim-dap",commit = "fc880e82059eb21c0fa896be60146e5f17680648" }
  use{
    "rcarriga/nvim-dap-ui",    requires = { "mfussenegger/nvim-dap" },    commit = "9720eb5fa2f41988e8770f973cd11b76dd568a5d"  }
  use{ "jayp0521/mason-nvim-dap.nvim", commit = "3614a39aae98ccd34124b072939d6283853b3dd2" }

  use{ "theHamsta/nvim-dap-virtual-text", commit = "d4542ac257d3c7ee4131350db6179ae6340ce40b" }
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
  use { "github/copilot.vim",commit = "79e1a892ca9b4fa6234fd25f2930dba5201700bd" }

  use { 'karb94/neoscroll.nvim',commit = "6e3546751076890304428150e53bd59198a4505d" }
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
,commit = "f2dd6d3bcf3309a7dd30c79b3b3c03ab55cea6e2" }

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
    "alexghergh/nvim-tmux-navigation",commit = "4898c98702954439233fdaf764c39636681e2861" }

  use {
    "stefandtw/quickfix-reflector.vim",
    commit = "6a6a9e28e1713b9e9db99eec1e6672e5666c01b9"
  }

  use {
    "stevearc/oil.nvim",
    commit = "6953c2c17d8ae7454b28c44c8767eebede312e6f"
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
