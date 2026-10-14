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
	"gopls",
	"jsonls",
	"lua_ls",
	"cssls",
	"bashls",
	"basedpyright",
	"ruff",
	"yamlls",
	"expert",
	"zls",
	"vtsls",
	"denols",
}

function M.servers()
	local is_deno = vim.fs.root(0, { "deno.json", "deno.jsonc" })
	local excluded = is_deno and "vtsls" or "denols"
	return vim.tbl_filter(function(name)
		return name ~= excluded
	end, M.configured)
end

return M
