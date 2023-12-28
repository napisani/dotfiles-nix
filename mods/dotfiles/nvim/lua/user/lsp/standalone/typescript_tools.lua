local nvim_lsp = require("lspconfig")
require("typescript-tools").setup {
  on_attach = require("user.lsp.handlers").on_attach,
  capabilities = require("user.lsp.handlers").capabilities,
  lsp_flags = require("user.lsp.handlers").lsp_flags,
  -- ft = { "typescript", "typescriptreact" },
  enabled = true, 
  -- on_attach = function() ... end,
  -- handlers = { ... },
  settings = {
    -- spawn additional tsserver instance to calculate diagnostics on it
    -- separate_diagnostic_server = true,
    -- "change"|"insert_leave" determine when the client asks the server about diagnostic
    -- publish_diagnostic_on = "insert_leave",
    -- string|nil -specify a custom path to `tsserver.js` file, if this is nil or file under path
    -- not exists then standard path resolution strategy is applied
    -- tsserver_path = nil,
    -- specify a list of plugins to load by tsserver, e.g., for support `styled-components`
    -- (see 💅 `styled-components` support section)
    -- tsserver_plugins = {},
    -- this value is passed to: https://nodejs.org/api/cli.html#--max-old-space-sizesize-in-megabytes
    -- memory limit in megabytes or "auto"(basically no limit)
    tsserver_max_memory = "auto",
    -- described below
    -- tsserver_format_options = {},
    -- tsserver_file_preferences = {},
  },
}
