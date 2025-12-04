require("user.lsp.mason")
require("mason-nvim-dap").setup({
	lazy = false,
	ensure_installed = { "python", "lldb", "node2", "chrome", "js" },
})

require("user.lsp.attach").setup()

vim.lsp.config("eslint", {
	single_file_support = true,
	settings = {
		packageManager = "yarn", -- or 'npm'
	},
})

vim.lsp.enable({
	"efm",
	"gopls",
	"jsonls",
	"lua_ls",
	"cssls",
	"bashls",
	-- "pyright",
	"basedpyright",
	"ruff",
	"yamlls",
--	"learnls",
})

-- For now, i need to completely disable vtsls for any projects that are
-- using deno, to avoid conflicts.
-- for some reason, the root_dir function and root_markers config options
-- are not working as expected for vtsls.
local is_deno = vim.fs.root(0, { "deno.json", "deno.jsonc" })

if is_deno then
	vim.lsp.enable({ "denols" })
else
	vim.lsp.enable({ "vtsls" })
end

vim.diagnostic.config({
	virtual_lines = false,
	virtual_text = false,

	underline = true,
	update_in_insert = true,
	severity_sort = true,
	float = {
		border = "rounded",
		source = true,
	},
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "󰅚 ",
			[vim.diagnostic.severity.WARN] = "󰀪 ",
			[vim.diagnostic.severity.INFO] = "󰋽 ",
			[vim.diagnostic.severity.HINT] = "󰌶 ",
		},
		numhl = {
			[vim.diagnostic.severity.ERROR] = "ErrorMsg",
			[vim.diagnostic.severity.WARN] = "WarningMsg",
		},
	},
})

vim.lsp.config("*", {
	root_markers = { ".git" },
})

vim.cmd([[ command! Format execute 'lua vim.lsp.buf.format{async=true}' ]])
