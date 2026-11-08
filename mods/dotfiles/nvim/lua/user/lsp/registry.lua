local M = {}

M.heavy = {
	vtsls = true,
	denols = true,
	basedpyright = true,
	pyright = true,
	pylsp = true,
	ruff = true,
}

M.configured = {
	"efm",
	"nil_ls",
	"gopls",
	"jsonls",
	"lua_ls",
	"cssls",
	"html",
	"eslint",
	"tailwindcss",
	"bashls",
	"basedpyright",
	"ruff",
	"yamlls",
	"zls",
	"vtsls",
	"denols",
}

-- Hosts install different servers: nil exists only where Nix provides it.
local function installed(name)
	local cmd = (vim.lsp.config[name] or {}).cmd
	return type(cmd) ~= "table" or vim.fn.executable(cmd[1]) == 1
end

function M.servers()
	local is_deno = vim.fs.root(0, { "deno.json", "deno.jsonc" })
	local excluded = is_deno and "vtsls" or "denols"
	return vim.tbl_filter(function(name)
		return name ~= excluded and installed(name)
	end, M.configured)
end

return M
