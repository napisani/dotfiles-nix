local status_ok, _ = pcall(require, "efmls-configs")
if not status_ok then
  vim.notify("efmls-configs not found")
  return
end

local utils = require("user.utils")
local eslint_d_lint = require("efmls-configs.linters.eslint_d")
local eslint_d_format = require("efmls-configs.formatters.eslint_d")

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
local isort = require("efmls-configs.formatters.isort")
local ruff_format = require("efmls-configs.formatters.ruff")
local ruff_lint = require("efmls-configs.linters.ruff")
local statix = require("efmls-configs.linters.statix")
local nixfmt = require("efmls-configs.formatters.nixfmt")

local project_lint_config = utils.get_project_config().lint or {}

local biome_custom = vim.tbl_extend("force", biome, {
  rootMarkers = { "biome.json" },
})


-- local oxlint = {
--   lintCommand = "./node_modules/.bin/oxlint lint ${INPUT} | sed -z 's/\\n/ /g' | sed -r 's/\\x1B\\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g' ",
--   lintStdin = false,
--   lintFormats = { "%f:%l:%c]%m" },
--   lintIgnoreExitCode = true,
--   lintSource = "oxlint",
-- }


local function get_js_linters()
  local linters = {}
  if utils.table_has_value(project_lint_config,"eslint") or next(project_lint_config) == nil then
    table.insert(linters, eslint_d_lint)
    table.insert(linters, eslint_d_format)
  end
  if utils.table_has_value(project_lint_config,"prettier") then
    table.insert(linters, prettier)
  end
  if utils.table_has_value(project_lint_config,"biome") then
    table.insert(linters, biome_custom)
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
  lua = { stylua },
  json = { fixjson, jq_lint, jq_format },
  jsonc = { fixjson, jq_lint, jq_format },
  python = { isort, ruff_format, ruff_lint },
}

local efmls_config = {
  filetypes = vim.tbl_keys(languages),
  settings = {
    rootMarkers = { ".git/" },
    languages = languages,
  },
  init_options = {
    documentFormatting = true,
    documentRangeFormatting = true,
  },
}

-- -- Format on save
-- local lsp_fmt_group = vim.api.nvim_create_augroup("LspFormattingGroup", {})
-- vim.api.nvim_create_autocmd("BufWritePost", {
-- 	group = lsp_fmt_group,
-- 	callback = function(ev)
-- 		local efm = vim.lsp.get_active_clients({ name = "efm", bufnr = ev.buf })

-- 		if vim.tbl_isempty(efm) then
-- 			return
-- 		end

-- 		vim.lsp.buf.format({ name = "efm" })
-- 	end,
-- })
return efmls_config