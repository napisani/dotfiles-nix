-- pipx install ruff ; pipx install ruff-lsp
local status_ok, lspconfig = pcall(require, "lspconfig")
if not status_ok then
  vim.notify('lspconfig not found')
  return
end

local on_attach = require("user.lsp.handlers").on_attach
lspconfig.ruff_lsp.setup {
  on_attach = on_attach
}
