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
  use { "nvim-lua/plenary.nvim",commit = "08e301982b9a057110ede7a735dd1b5285eb341f" }

  -- Autopairs, integrates with both cmp and treesitter
  use { "windwp/nvim-autopairs",commit = "14e97371b2aab6ee70054c1070a123dfaa3e217e" }

  use { "tpope/vim-commentary",commit = "c4b8f52cbb7142ec239494e5a2c4a512f92c4d07" }
  use { "JoosepAlviste/nvim-ts-context-commentstring",commit = "0bdccb9c67a42a5e2d99384dc9bfa29b1451528f" }
  use { "kyazdani42/nvim-web-devicons",commit = "5b9067899ee6a2538891573500e8fd6ff008440f" }
  use { "kyazdani42/nvim-tree.lua",commit = "64f61e4c913047a045ff90bd188dd3b54ee443cf" }
  use { "akinsho/bufferline.nvim",commit = "73540cb95f8d95aa1af3ed57713c6720c78af915" }
  use { "moll/vim-bbye", commit = "25ef93ac5a87526111f43e5110675032dbcacf56" }
  use { "nvim-lualine/lualine.nvim",commit = "0a5a66803c7407767b799067986b4dc3036e1983" }

  use { "ahmedkhalf/project.nvim", commit = "8c6bad7d22eef1b71144b401c9f74ed01526a4fb" }
  use { "lewis6991/impatient.nvim", commit = "47302af74be7b79f002773011f0d8e85679a7618" }
  use { "lukas-reineke/indent-blankline.nvim",commit = "3d08501caef2329aba5121b753e903904088f7e6" }

  use { "goolord/alpha-nvim",commit = "41283fb402713fc8b327e60907f74e46166f4cfd" }
  use { "folke/which-key.nvim" }

  -- Colorschemes
  -- use { "folke/tokyonight.nvim",commit = "9a01eada39558dc3243278e6805d90e8dff45dc0" }
  -- use { "morhetz/gruvbox",commit = "f1ecde848f0cdba877acb0c740320568252cc482" }
  -- use { "shaunsingh/nord.nvim",commit = "15fbfc38a83980b93e169b32a1bf64757f1e2bf4" }
  use { "rebelot/kanagawa.nvim",commit = "860e4f80df71221d18bf2cd9ef1deb4d364274d2" }

  -- Cmp
  -- The completion plugin
  use { "hrsh7th/nvim-cmp",commit = "cd2cf0c124d3de577fb5449746568ee8e601afc8" }
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
  use { "L3MON4D3/LuaSnip",commit = "b152822e1a4bafb6bdf11a16cc26525cbd95ee00" }
  -- a bunch of snippets to use
  use { "rafamadriz/friendly-snippets",commit = "3e9a3f5a0cfcef1741e352c37bda4e82e5eb846a" }

  -- LSP
  use { "neovim/nvim-lspconfig",commit = "a3d9395455f2b2e3b50a0b0f37b8b4c23683f44a" }
  -- simple to use language server installer
  use { "williamboman/mason.nvim",
    run = ":MasonUpdate" -- :MasonUpdate updates registry contents
  }
  use { "williamboman/mason-lspconfig.nvim",commit = "05744f0f1967b5757bd05c08df4271ab8ec990aa" }
  -- for formatters and linters
  use { "jose-elias-alvarez/null-ls.nvim", commit = "0010ea927ab7c09ef0ce9bf28c2b573fc302f5a7" }
  use { "RRethy/vim-illuminate",commit = "e522e0dd742a83506db0a72e1ced68c9c130f185" }
  use {
    'creativenull/efmls-configs-nvim',tag = 'v1.*',requires = { 'neovim/nvim-lspconfig' },commit = "f477186ecc12ac025a9948d17edc69242e1ee96b"
  }

  -- Telescope
  use { "nvim-telescope/telescope.nvim",commit = "fac83a556e7b710dc31433dec727361ca062dbe9" }
  use { "nvim-telescope/telescope-file-browser.nvim",commit = "4d5fd21bae12ee6e9a79232e1c377f43c419d0c5" }
  use {
    "benfowler/telescope-luasnip.nvim", commit = "2ef7da3a363890686dbaad18ddbf59177cfe4f78"
  }

  -- Treesitter
  use {
    "nvim-treesitter/nvim-treesitter",commit = "1be5aa99e3e0e4a36c31fa7066dcf46a4e0142dd" }

  -- Git
  use { "lewis6991/gitsigns.nvim" }
  use { "tpope/vim-fugitive",commit = "ce882460cf3db12e99f8bf579cbf99e331f6dd4f" }
  use {
    "sindrets/diffview.nvim", requires = "nvim-lua/plenary.nvim", commit = "3dc498c9777fe79156f3d32dddd483b8b3dbd95f" }

  use {
    "NeogitOrg/neogit",    requires = {
      "nvim-lua/plenary.nvim",         -- required
      "sindrets/diffview.nvim",        -- optional - Diff integration

      "nvim-telescope/telescope.nvim", -- optional
    },    commit = "c5e09bfcc18fa9ffc5394c3b58ef94d69f85608a"
  }

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
  use{ "mfussenegger/nvim-dap",commit = "6ae8a14828b0f3bff1721a35a1dfd604b6a933bb" }
  use{
    "rcarriga/nvim-dap-ui",requires = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },commit = "5934302d63d1ede12c0b22b6f23518bb183fc972"  }
  use{ "jayp0521/mason-nvim-dap.nvim",commit = "67210c0e775adec55de9826b038e8b62de554afc" }

  use{ "theHamsta/nvim-dap-virtual-text",commit = "3e8e207513e6ef520894950acd76b79902714103" }
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
  use { "github/copilot.vim",commit = "b603990a639bb4b8651d054ef8d5a8fe5db56e0c" }

  use { 'karb94/neoscroll.nvim',commit = "e78657719485c5663b88e5d96ffcfb6a2fe3eec0" }
  use { 'hkupty/iron.nvim',commit = "81733bfd30309c916b52b95aab473257e3631a7a" }

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
    'glacambre/firenvim',    run = function() vim.fn['firenvim#install'](0) end,    commit = "03ba12a5a92a02d171005775a8150998c4060a74" 
  }

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
    "stevearc/oil.nvim",commit = "010b44a79d497c697686e2727049d3dd215bbbd6"
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
