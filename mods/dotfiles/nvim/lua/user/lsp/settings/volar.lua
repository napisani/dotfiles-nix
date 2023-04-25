local is_npm_package_installed = require('user.utils').is_npm_package_installed
--return {
--  filetypes = is_npm_package_installed 'vue' and { 'vue', 'typescript', 'javascript' } or { 'vue' },
--  init_options = {
--    typescript = {
--        --serverPath = '/Users/nick/.nvm/versions/node/v16.16.0/lib/node_modules/typescript/lib/tsserverlibrary.js',
--      tsdk = '/Users/nick/code/clearing-app2/node_modules/typescript/lib'
--      --tsdk = '/Users/nick/.nvm/versions/node/v16.16.0/lib/node_modules/typescript/lib/'
--      -- Alternative location if installed as root:
--      -- tsdk = '/usr/local/lib/node_modules/typescript/lib'
--    }
--  },
--}

-- local on_attach = require("user.lsp.handlers").on_attach
-- require'lspconfig'.volar.setup
local utils = require("user.utils")
return {
  -- take over mode - defined here: https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#volar
  filetypes = {'typescript', 'javascript', 'javascriptreact', 'typescript.tsx', 'typescriptreact', 'vue', 'json'},
  init_options = {
    typescript = {
      tsdk = utils.global_node_modules() .. '/typescript/lib'
      -- Alternative location if installed as root:
      -- tsdk = '/usr/local/lib/node_modules/typescript/lib'
    }
  }
}
