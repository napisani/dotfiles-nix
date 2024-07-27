local status_ok, lspconfig = pcall(require, "lspconfig")
if not status_ok then
	vim.notify("lspconfig not found")
	return
end

require("user.lsp.mason")
require("user.lsp.handlers").setup()
local utils = require("user.utils")
require("mason-nvim-dap").setup({
	lazy = false,
	ensure_installed = { "python", "lldb", "node2", "chrome", "js" },
})

-- any LSP plugins not configured through mason
require("user.lsp.standalone.rust_tools")
