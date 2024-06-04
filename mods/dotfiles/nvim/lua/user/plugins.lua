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
  use { "windwp/nvim-autopairs",commit = "c15de7e7981f1111642e7e53799e1211d4606cb9" }

  use { "tpope/vim-commentary",commit = "c4b8f52cbb7142ec239494e5a2c4a512f92c4d07" }
  use { "JoosepAlviste/nvim-ts-context-commentstring",commit = "cb064386e667def1d241317deed9fd1b38f0dc2e" }
  use { "kyazdani42/nvim-web-devicons",commit = "b77921fdc44833c994fdb389d658ccbce5490c16" }
  use { "kyazdani42/nvim-tree.lua",commit = "26632f496e7e3c0450d8ecff88f49068cecc8bda" }
  use { "akinsho/bufferline.nvim",commit = "99337f63f0a3c3ab9519f3d1da7618ca4f91cffe" }
  use { "moll/vim-bbye", commit = "25ef93ac5a87526111f43e5110675032dbcacf56" }
  use { "nvim-lualine/lualine.nvim",commit = "0a5a66803c7407767b799067986b4dc3036e1983" }

  use { "ahmedkhalf/project.nvim", commit = "8c6bad7d22eef1b71144b401c9f74ed01526a4fb" }
  use { "lewis6991/impatient.nvim", commit = "47302af74be7b79f002773011f0d8e85679a7618" }
  use { "lukas-reineke/indent-blankline.nvim",commit = "d98f537c3492e87b6dc6c2e3f66ac517528f406f" }

  use { "goolord/alpha-nvim",commit = "41283fb402713fc8b327e60907f74e46166f4cfd" }
  use { "folke/which-key.nvim" }

  -- Colorschemes
  -- use { "folke/tokyonight.nvim",commit = "9a01eada39558dc3243278e6805d90e8dff45dc0" }
  -- use { "morhetz/gruvbox",commit = "f1ecde848f0cdba877acb0c740320568252cc482" }
  -- use { "shaunsingh/nord.nvim",commit = "15fbfc38a83980b93e169b32a1bf64757f1e2bf4" }
  use { "rebelot/kanagawa.nvim",commit = "08ed29989834f5f2606cb1ef9d5b24c5ea7b8fa5" }

  -- Cmp
  -- The completion plugin
  use { "hrsh7th/nvim-cmp",commit = "5260e5e8ecadaf13e6b82cf867a909f54e15fd07" }
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
  use { "L3MON4D3/LuaSnip",commit = "2b6860d15aaab01d3fb90859c0ba97f20ad7bc5f" }
  -- a bunch of snippets to use
  use { "rafamadriz/friendly-snippets",commit = "e11b09bf10706bb74e16e4c3d11b2274d62e687f" }

  -- LSP
  use { "neovim/nvim-lspconfig",commit = "74e14808cdb15e625449027019406e1ff6dda020" }
  -- simple to use language server installer
  use { "williamboman/mason.nvim",
    run = ":MasonUpdate" -- :MasonUpdate updates registry contents
  }
  use { "williamboman/mason-lspconfig.nvim",commit = "a4caa0d083aab56f6cd5acf2d42331b74614a585" }
  -- for formatters and linters
  use { "jose-elias-alvarez/null-ls.nvim", commit = "0010ea927ab7c09ef0ce9bf28c2b573fc302f5a7" }
  use { "RRethy/vim-illuminate",commit = "5eeb7951fc630682c322e88a9bbdae5c224ff0aa" }
  use {
    'creativenull/efmls-configs-nvim',tag = 'v1.*',requires = { 'neovim/nvim-lspconfig' },commit = "eb2be5b24dbf7200a80bcd5c64bc63afbc8ae86f"
  }

  -- Telescope
  use { "nvim-telescope/telescope.nvim",commit = "dfa230be84a044e7f546a6c2b0a403c739732b86" }
  use { "nvim-telescope/telescope-file-browser.nvim",commit = "1280db1f835bd6b73a485d6f1149e02df67533c4" }
  use {
    "benfowler/telescope-luasnip.nvim", commit = "2ef7da3a363890686dbaad18ddbf59177cfe4f78"
  }

  -- Treesitter
  use {
    "nvim-treesitter/nvim-treesitter",commit = "a80fe081b4c5890980561e0de2458f64aaffbfc7" }

  -- Git
  use { "lewis6991/gitsigns.nvim" }
  use { "tpope/vim-fugitive",commit = "4f59455d2388e113bd510e85b310d15b9228ca0d" }
  use {
    "sindrets/diffview.nvim",requires = "nvim-lua/plenary.nvim",commit = "3afa6a053f680e9f1329c4a151db988a482306cd" }

  use {

    "NeogitOrg/neogit",
    requires = {
      "nvim-lua/plenary.nvim",         -- required
      "sindrets/diffview.nvim",        -- optional - Diff integration

      "nvim-telescope/telescope.nvim", -- optional
    },
    commit = "3d58bf1d548f6fafdaab8ce4d75e25c438aee92c"
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
    "phaazon/hop.nvim", branch = "v2", commit = "90db1b2c61b820e230599a04fedcd2679e64bd07" }
  -- use 'ggandor/lightspeed.nvim'
  -- use{ "ggandor/leap.nvim", commit = "f7391b5fe9771d788816383ee3c75e0be92022af" }

  -- debugging
  use{ "mfussenegger/nvim-dap",commit = "6f79b822997f2e8a789c6034e147d42bc6706770" }
  use{
    "rcarriga/nvim-dap-ui",requires = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },commit = "b7267003ba4dd860350be86f75b9d9ea287cedca"  }
  use{ "jayp0521/mason-nvim-dap.nvim",commit = "67210c0e775adec55de9826b038e8b62de554afc" }

  use{ "theHamsta/nvim-dap-virtual-text",commit = "d7c695ea39542f6da94ee4d66176f5d660ab0a77" }
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
  use { "smartpde/neoscopes", commit = "470dff042004b93c10d262e8b0ad7bf6f703f86f" }

  -- use { "napisani/neoscopes" }
  -- use('/Users/nick/code/neoscopes')
  -- use('/Users/nick/code/nvim-github-codesearch')
  use { 'napisani/nvim-github-codesearch', run = 'nix-shell make' }

  -- use {'napisani/nvim-search-rules' }
  -- use { '/Users/nick/code/nvim-search-rules' }

  -- copilot
  use { "github/copilot.vim",commit = "53d3091be388ff1edacdb84421ccfa19a446a84d" }

  use { 'karb94/neoscroll.nvim',commit = "a731f66f1d39ec6175fd201c5bf849e54abda99c" }
  use { 'hkupty/iron.nvim',commit = "c993d018d11829528b0fe91eb9ba412e453071ea" }

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
    'glacambre/firenvim',run = function() vim.fn['firenvim#install'](0) end,commit = "cf4ff99033640b5ec33890bcdc892ddc436ed8e5" 
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
    "stevearc/oil.nvim",commit = "bbc0e67eebc15342e73b146a50d9b52e6148161b"
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
