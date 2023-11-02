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

local M = {}
local servers = {
	angularls = { npm = "@angular/language-server" },
	bashls = {},
	cssls = {},
	-- denols = {},
  gopls = {},
	docker_compose_language_service = {},
	dockerls = {},
	html = {},
	jsonls = { npm = "vscode-langservers-extracted" },
	lua_ls = { brew = "lua-language-server" },
	pyright = { npm = "pyright" },
	rnix = {},
	ruff_lsp = { pipx = "ruff-lsp" },
  -- vim_dadbod_completion = {},
	-- sqlls = {}, -- https://github.com/lighttiger2505/sqls/releases
  -- this one is old but it works great
	-- sqls = {},
	tailwindcss = {},
	taplo = {},
	tsserver = { npm = "typescript-language-server" , skip = true}, -- npm install -g typescript typescript-language-server
	vls = { npm = "vls" }, -- npm install -g @volar/vue-language-server
	yamlls = {},
  -- nil_ls = {},false
}
local servers_only = {}
for server, _ in pairs(servers) do
	table.insert(servers_only, server)
end

mason.setup({})
mason_lspconfig.setup({
	ensure_installed = servers_only,
	automatic_installation = true,
})

for server, server_config in pairs(servers) do
	local opts = {
		on_attach = require("user.lsp.handlers").on_attach,
		lsp_flags = require("user.lsp.handlers").lsp_flags,
	}
	local has_custom_opts, server_custom_opts = pcall(require, "user.lsp.settings." .. server)
	if has_custom_opts then
		local global_on_attach = opts.on_attach
		local on_attach_temp = global_on_attach
		if server_custom_opts["server"] ~= nil and server_custom_opts["server"]["on_attach"] ~= nil then
			local override_on_attach = server_custom_opts.server.on_attach
			local on_attach_temp = function(client, bufnr)
				global_on_attach(client, bufnr)
				override_on_attach(client, bufnr)
			end
		end
		opts = vim.tbl_deep_extend("force", opts, server_custom_opts)
		opts["on_attach"] = on_attach_temp
	end
	-- require('user.utils').print(opts['init_opts'])
	-- require('user.utils').print(server)
  if  server_config.skip  ~= true then
    lspconfig[server].setup(opts)
  end
end

function M.install()
	for server, server_config in pairs(servers) do
		if server_config.brew ~= nil then
			print("brew install " .. server_config.brew)
			os.execute("brew install " .. server_config.brew)
		elseif server_config.npm ~= nil then
			print("npm install -g " .. server_config.npm)
			os.execute("npm install -g " .. server_config.npm)
		elseif server_config.pipx ~= nil then
			print("pipx install " .. server_config.pipx)
			os.execute("pipx install " .. server_config.pipx)
		end
	end
end

return M
