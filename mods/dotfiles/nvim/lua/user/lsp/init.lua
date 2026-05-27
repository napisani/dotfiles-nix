require("user.lsp.mason")
require("mason-nvim-dap").setup({
	lazy = false,
	ensure_installed = { "python", "lldb", "chrome", "js", "delve" },
})

require("user.lsp.attach").setup()

local inline_group = vim.api.nvim_create_augroup("user_lsp_inline_completion", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
	group = inline_group,
	callback = function(args)
		local client_id = args.data and args.data.client_id
		if not client_id then
			return
		end
		local client = vim.lsp.get_clients({ id = client_id })[1]
		if not client then
			return
		end
		local inline = vim.lsp.inline_completion
		if not inline or type(inline.enable) ~= "function" then
			return
		end
		-- Enable inline completion if the server supports it, or unconditionally for copilot
		-- (copilot-language-server may not advertise the capability in serverCapabilities)
		local supports_inline = client.supports_method
			and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, args.buf)
		if client.name == "copilot" then
			require("user.plugins.ai.copilot").enable_for_client(client, args.buf)
		elseif supports_inline then
			inline.enable(true, { bufnr = args.buf })
		end
	end,
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
	"expert",
	"zls",
})

vim.lsp.enable("copilot")

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

vim.api.nvim_create_user_command("Format", function()
	vim.lsp.buf.format({ async = true })
end, {})
