local status_ok, mason = pcall(require, "mason")
if not status_ok then
	vim.notify("mason not found")
	return
end
local status_ok, mason_lspconfig = pcall(require, "mason-lspconfig")
if not status_ok then
	vim.notify("mason not found")
	return
end
local utils = require("user.utils")

local project_lint_config = utils.get_project_config().lint or {}
local biome_enabled = utils.table_has_value(project_lint_config, "biome")
local M = {}
local servers = {
	"angularls",
	"bashls",
	"cssls",
	"gopls",
	"denols",
	"docker_compose_language_service",
	"dockerls",
	"html",
	"jsonls",
	"lua_ls",
	-- "pyright",
  "basedpyright",
	"ruff",
	"tailwindcss",
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

local client_to_fix_import_fns = {}

M.fix_all_imports = function()
	local active_clients = vim.lsp.get_clients()
	for _, client in ipairs(active_clients) do
		local client_name = client.name
		local fn = client_to_fix_import_fns[client_name]
		if fn then
			-- vim.notify("fixing imports for " .. client_name)
			fn()
		end
	end
end

return M
