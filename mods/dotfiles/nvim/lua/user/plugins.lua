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

  use { "tpope/vim-commentary", commit = "e87cd90dc09c2a203e13af9704bd0ef79303d755" }
  use { "JoosepAlviste/nvim-ts-context-commentstring",commit = "1277b4a1f451b0f18c0790e1a7f12e1e5fdebfee" }
  use { "kyazdani42/nvim-web-devicons",commit = "43aa2ddf476012a2155f5f969ee55ab17174da7a" }
  use { "kyazdani42/nvim-tree.lua",commit = "50f30bcd8c62ac4a83d133d738f268279f2c2ce2" }
  use { "akinsho/bufferline.nvim",commit = "e48ce1805697e4bb97bc171c081e849a65859244" }
  use { "moll/vim-bbye", commit = "25ef93ac5a87526111f43e5110675032dbcacf56" }
  use { "nvim-lualine/lualine.nvim", commit = "2248ef254d0a1488a72041cfb45ca9caada6d994" }

  use { "ahmedkhalf/project.nvim", commit = "8c6bad7d22eef1b71144b401c9f74ed01526a4fb" }
  use { "lewis6991/impatient.nvim", commit = "47302af74be7b79f002773011f0d8e85679a7618" }
  use { "lukas-reineke/indent-blankline.nvim",commit = "0dca9284bce128e60da18693d92999968d6cb523" }

  use { "goolord/alpha-nvim",commit = "29074eeb869a6cbac9ce1fbbd04f5f5940311b32" }
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
  use { "L3MON4D3/LuaSnip",commit = "57c9f5c31b3d712376c704673eac8e948c82e9c1" }
  -- a bunch of snippets to use
  use { "rafamadriz/friendly-snippets",commit = "53d3df271d031c405255e99410628c26a8f0d2b0" }

  -- LSP
  use { "neovim/nvim-lspconfig",commit = "9099871a7c7e1c16122e00d70208a2cd02078d80" }
  -- simple to use language server installer
  use { "williamboman/mason.nvim",
    run = ":MasonUpdate" -- :MasonUpdate updates registry contents
  }
  use { "williamboman/mason-lspconfig.nvim",commit = "56e435e09f8729af2d41973e81a0db440f8fe9c9" }
  -- for formatters and linters
  use { "jose-elias-alvarez/null-ls.nvim", commit = "0010ea927ab7c09ef0ce9bf28c2b573fc302f5a7" }
  use { "RRethy/vim-illuminate", commit = "3bd2ab64b5d63b29e05691e624927e5ebbf0fb86" }
  use {
    'creativenull/efmls-configs-nvim',    tag = 'v1.*',    requires = { 'neovim/nvim-lspconfig' },    commit = "ddc7c542aaad21da594edba233c15ae3fad01ea0"
  }

  -- Telescope
  use { "nvim-telescope/telescope.nvim",commit = "ae6708a90b89a686f85b51288f488f4186dff2d4" }
  use { "nvim-telescope/telescope-file-browser.nvim",commit = "8e0543365fe5781c9babea7db89ef06bcff3716d" }
  use {
    "benfowler/telescope-luasnip.nvim", commit = "2ef7da3a363890686dbaad18ddbf59177cfe4f78"
  }

  -- Treesitter
  use {
    "nvim-treesitter/nvim-treesitter",commit = "27f68c0b6a87cbad900b3d016425450af8268026" }

  -- Git
  use { "lewis6991/gitsigns.nvim" }
  use { "tpope/vim-fugitive",commit = "59659093581aad2afacedc81f009ed6a4bfad275" }
  use {
    "sindrets/diffview.nvim", requires = "nvim-lua/plenary.nvim", commit = "3dc498c9777fe79156f3d32dddd483b8b3dbd95f" }

  -- vim.notify notifications
  use { "rcarriga/nvim-notify",commit = "27a6649ba6b22828ccc67c913f95a5407a2d8bec" }

  -- Rust tools
  use { "simrat39/rust-tools.nvim", commit = "0cc8adab23117783a0292a0c8a2fbed1005dc645" }

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
  use { "mfussenegger/nvim-dap",commit = "f0dca670fa059eb89dda8869a6310c804241345c" }
  use {
    "rcarriga/nvim-dap-ui", requires = { "mfussenegger/nvim-dap" }, commit = "34160a7ce6072ef332f350ae1d4a6a501daf0159" }
  use { "jayp0521/mason-nvim-dap.nvim",commit = "9e82ded0515186edd4f69e4ce6b1a5f1b55b47e9" }
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
  use { "github/copilot.vim",commit = "5b19fb001d7f31c4c7c5556d7a97b243bd29f45f" }

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
    'glacambre/firenvim', run = function() vim.fn['firenvim#install'](0) end
  , commit = "138424db463e6c0e862a05166a4ccc781cd7c19d" }

  use {
    "pmizio/typescript-tools.nvim",requires = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },commit =
  "829b5dc4f6704b249624e5157ad094dcb20cdc6b"
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

  use {
    "stevearc/oil.nvim",commit = "22ab2ce1d56832588a634e7737404d9344698bd3" }

  -- use('/Users/nick/code/monoscope')
  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end

-- Install your plugins here
return packer.startup(define_plugins)
