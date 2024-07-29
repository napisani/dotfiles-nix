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
local lspconfig = require("lspconfig")
local utils = require("user.utils")

local project_lint_config = utils.get_project_config().lint or {}
local biome_enabled = utils.table_has_value(project_lint_config, "biome")
local M = {}
local servers = {
	angularls = { npm = "@angular/language-server" },
	bashls = {},
	cssls = {},

	gopls = {},
	docker_compose_language_service = {},
	dockerls = {},
	html = {},
	jsonls = { npm = "vscode-langservers-extracted" },
	lua_ls = { brew = "lua-language-server" },
	pyright = { npm = "pyright" },
	-- biome = { npm = "@biomejs/biome", skip = not biome_enabled },
	-- rnix = {},
	ruff_lsp = { pipx = "ruff-lsp" },
	-- vim_dadbod_completion = {},
	-- sqlls = {}, -- https://github.com/lighttiger2505/sqls/releases
	-- this one is old but it works great
	-- sqls = {},
	tailwindcss = {},
	taplo = {},
	-- tsserver = { npm = "typescript-language-server", skip = true }, -- npm install -g typescript typescript-language-server
	denols = {},
	yamlls = {},
	vtsls = {
		npm = "@vtsls/language-server",
	},
	efm = {},
	-- nil_ls = {},
}

local servers_only = {}
for server, _ in pairs(servers) do
	-- nil_ls will not install from mason rely on the neovim nix flake
	if server ~= "nil_ls" and server ~= "biome" then
		table.insert(servers_only, server)
	end
end

mason.setup({})
mason_lspconfig.setup({
	ensure_installed = servers_only,
	automatic_installation = true,
})

local client_to_fix_import_fns = {}

M.fix_all_imports = function()
	local active_clients = vim.lsp.get_active_clients()
	for _, client in ipairs(active_clients) do
		local client_name = client.name
		local fn = client_to_fix_import_fns[client_name]
		if fn then
			-- vim.notify("fixing imports for " .. client_name)
			fn()
		end
	end
end

for server, server_config in pairs(servers) do
	local opts = {
		on_attach = require("user.lsp.handlers").on_attach,
		lsp_flags = require("user.lsp.handlers").lsp_flags,
	}
	local has_custom_opts, server_custom_opts = pcall(require, "user.lsp.settings." .. server)
	if has_custom_opts then
		local global_on_attach = opts.on_attach
		local on_attach_temp = global_on_attach

		if server_custom_opts["server"] ~= nil then
			local custom_server_opts = server_custom_opts["server"]
			client_to_fix_import_fns[server] = custom_server_opts["fix_all_imports"]

			if custom_server_opts["on_attach"] ~= nil then
				local override_on_attach = custom_server_opts.on_attach
				on_attach_temp = function(client, bufnr)
					global_on_attach(client, bufnr)
					override_on_attach(client, bufnr)
				end
			end
		end
		opts = vim.tbl_deep_extend("force", opts, server_custom_opts)
		opts["on_attach"] = on_attach_temp
	end

	-- require('user.utils').print(opts['init_opts'])
	-- require('user.utils').print(server)
	if server_config.skip ~= true then
		lspconfig[server].setup(opts)
	end
end

return M
