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
	jsonls = {
    npm = "vscode-langservers-extracted"
  },
	-- "sumneko_lua",
	-- brew install lua-language-server
	lua_ls = {
    brew = "lua-language-server",
  },
	cssls = {},
	tailwindcss = {},
	html = {},
	-- "jedi_language_server",
	-- "pylsp",
	--'angular-language-server',    -- npm install -g @angular/language-server
	angularls = {
    npm = "@angular/language-server"
  },
	--'diagnosticls',  -- npm install -g diagnostic-languageserver
	--'eslint',                 -- npm install -g eslint_d
	--'flake8',                     -- python -m pip install -U flake8
	--'json-lsp',                   -- npm install -g vscode-langservers-extracted
  -- 'json-lsp'= {
  --   npm = "vscode-langservers-extracted"
  -- },
	--'lua-language-server',        -- install via package manager
	--'mypy',                       -- python -m pip install -U mypy
	pyright = {
    npm = "pyright"
  }, -- npm install -g pyright
	--'shellcheck',                 -- install via package manager
	--'bashls',
	sqlls = {}, -- https://github.com/lighttiger2505/sqls/releases
	tsserver = {
    npm = "typescript-language-server"
  }, -- npm install -g typescript typescript-language-server
	vls = {
    -- npm = "@volar/vue-language-server"
    npm = "vls"
  }, -- npm install -g @volar/vue-language-server
	ruff_lsp = {
    pipx = "ruff-lsp"
  }, -- pipx install ruff ; pipx install ruff-lsp
	--'typescript-language-server', -- npm install -g typescript typescript-language-server
	--'vue-language-server',        -- npm install -g @volar/vue-language-server
	--'vuels'
	--'volar'
	--'vetur-vls',                  -- npm install -g vls
}

mason_lspconfig.setup({
	-- ensure_installed = servers,
})

external_tools = {}

for server, server_config in pairs(servers) do
	local opts = {
		on_attach = require("user.lsp.handlers").on_attach,
		capabilities = require("user.lsp.handlers").capabilities,
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
	lspconfig[server].setup(opts)
end

function M.install()
  for server, server_config in pairs(servers) do
    if server_config.brew ~= nil then
      print('brew install ' .. server_config.brew)
      os.execute("brew install " .. server_config.brew)
    elseif server_config.npm ~= nil then
      print('npm install -g ' .. server_config.npm)
      os.execute("npm install -g " .. server_config.npm)
    elseif server_config.pipx ~= nil then
      print('pipx install ' .. server_config.pipx)
      os.execute("pipx install " .. server_config.pipx)
    end
  end

end
return M
