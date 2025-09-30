local status_ok, _ = pcall(require, "efmls-configs")
if not status_ok then
	vim.notify("efmls-configs not found")
	return
end

local utils = require("user.utils")
local eslint_d_lint = require("efmls-configs.linters.eslint_d")
local eslint_d_format = require("efmls-configs.formatters.eslint_d")

-- local nvim_lsp = require("lspconfig")

local prettier = require("efmls-configs.formatters.prettier")
local stylua = require("efmls-configs.formatters.stylua")
local fixjson = require("efmls-configs.formatters.fixjson")
local jq_lint = require("efmls-configs.linters.jq")
local jq_format = require("efmls-configs.formatters.jq")
local shfmt = require("efmls-configs.formatters.shfmt")
local shellcheck = require("efmls-configs.linters.shellcheck")
local gofmt = require("efmls-configs.formatters.gofmt")
local goimports = require("efmls-configs.formatters.goimports")
local biome = require("efmls-configs.formatters.biome")
local deno_fmt = require("efmls-configs.formatters.deno_fmt")
local isort = require("efmls-configs.formatters.isort")
local ruff_format = require("efmls-configs.formatters.ruff")
local ruff_lint = require("efmls-configs.linters.ruff")
local statix = require("efmls-configs.linters.statix")
local nixfmt = require("efmls-configs.formatters.nixfmt")
local cspell = require("efmls-configs.linters.cspell")
local google_java_format = require("efmls-configs.formatters.google_java_format")
local gleam_format = require("efmls-configs.formatters.gleam_format")

local project_lint_config = utils.get_project_config().lint or {}

local biome_custom_format = vim.tbl_extend("force", biome, {
	rootMarkers = { "biome.json" },
})

function is_deno_project()
	-- local matcher = nvim_lsp.util.root_pattern("deno.json", "deno.jsonc")
	-- local deno_found = matcher(vim.fn.expand("%:p"))
	-- if deno_found then
	-- 	return true
	-- end
	return false
end

local function get_js_linters()
	local deno_found = is_deno_project()
	local linters = {}
	if next(project_lint_config) == nil then
		if deno_found then
			table.insert(linters, deno_fmt)
		else
			table.insert(linters, eslint_d_lint)
			table.insert(linters, eslint_d_format)
		end

		-- local file = io.open("/tmp/output.txt", "w")
		-- if file then
		-- 	file:write(vim.inspect(eslint_d_lint))
		-- 	file:write(vim.inspect(eslint_d_format))
		-- 	file:close()
		-- else
		-- 	print("Error: Unable to open file for writing")
		-- end
		return linters
	end
	for _, value in ipairs(project_lint_config) do
		if value == "eslint" then
			table.insert(linters, eslint_d_lint)
			table.insert(linters, eslint_d_format)
		end
		if value == "prettier" then
			table.insert(linters, prettier)
		end
		if value == "biome" then
			table.insert(linters, biome_custom_format)
		end
		if value == "deno" then
			table.insert(linters, deno_fmt)
		end
	end

	return linters
end

local languages = {
	go = { gofmt, goimports },
	nix = { nixfmt, statix },
	sh = { shellcheck, shfmt },
	typescript = get_js_linters(),
	javascript = get_js_linters(),
	typescriptreact = get_js_linters(),
	javascriptreact = get_js_linters(),
	vue = get_js_linters(),
	htmlangular = get_js_linters(),
	html = get_js_linters(),
	lua = { stylua },
	json = { fixjson, jq_lint, jq_format },
	jsonc = { fixjson, jq_lint, jq_format },
	python = { isort, ruff_format, ruff_lint },
	java = { google_java_format },
	gleam = { gleam_format },
}

-- add linters to all languages
if next(project_lint_config) == nil then
	for _, linters in pairs(languages) do
		table.insert(linters, cspell)
	end
else
	for _, linters in pairs(languages) do
		for _, value in ipairs(project_lint_config) do
			if value == "cspell" then
				table.insert(linters, cspell)
			end
		end
	end
end

local efmls_config = {
	filetypes = vim.tbl_keys(languages),
	settings = {
		rootMarkers = { ".git/", "package.json" },
		languages = languages,
	},
	init_options = {
		documentFormatting = true,
		documentRangeFormatting = true,
	},
}

return efmls_config
