local mason_ok, mason = pcall(require, "mason")
if not mason_ok then
	vim.notify("mason not found")
	return
end
local mason_lsp_ok, mason_lspconfig = pcall(require, "mason-lspconfig")
if not mason_lsp_ok then
	vim.notify("mason-lspconfig not found")
	return
end
local M = {}
local servers = {
	"bashls",
	"cssls",
	"gopls",
	"denols",
	"expert",
	"jsonls",
	"lua_ls",
	"copilot",
	-- "pyright",
	"basedpyright",
	"ruff",
	"yamlls",
	"vtsls",
	"efm",
}

mason.setup({})

mason_lspconfig.setup({
	automatic_enable = false,
	ensure_installed = servers,
	automatic_installation = true,
})

return M
