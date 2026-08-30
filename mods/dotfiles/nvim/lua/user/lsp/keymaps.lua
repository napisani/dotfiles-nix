-- Buffer LSP maps applied on attach. Neovim 0.11+ also defines stock `g*` maps (e.g. `grn` rename,
-- `gra` code action, `grr` references); see `:h lsp-defaults`. These `<leader>l*` / `gr` maps stay as
-- the primary discoverable bindings (which-key, tiny-code-action for `la`).
local M = {}

--- Filters out locations outside the active scope or in a disabled scope
--- category before populating the location list.
local function filtered_on_list(list_ctx)
	local path = require("user.scope.path")
	local category = require("user.scope.category")
	list_ctx.items = vim.tbl_filter(function(item)
		return path.is_visible(item.filename) and category.is_visible(item.filename)
	end, list_ctx.items)
	vim.fn.setloclist(0, {}, " ", list_ctx)
	vim.cmd.lopen()
end

M.base = {
	{ key = "gd", action = vim.lsp.buf.definition, desc = "Go to definition", method = "textDocument/definition" },
	-- { key = "gD", action = vim.lsp.buf.declaration, desc = "Go to declaration", method = "textDocument/declaration" },
	-- { key = "K", action = vim.lsp.buf.hover, desc = "Hover", method = "textDocument/hover" },
	{
		key = "gi",
		action = function()
			vim.lsp.buf.implementation(nil, { on_list = filtered_on_list })
		end,
		desc = "Go to implementation",
		method = "textDocument/implementation",
	},
	{
		key = "gr",
		action = function()
			vim.lsp.buf.references(nil, { on_list = filtered_on_list })
		end,
		desc = "References",
		method = "textDocument/references",
	},
	{
		key = "<leader>K",
		action = vim.lsp.buf.signature_help,
		desc = "Signature help",
		method = "textDocument/signatureHelp",
	},
	{ key = "<leader>lr", action = vim.lsp.buf.rename, desc = "Rename", method = "textDocument/rename" },
	{
		key = "<leader>la",
		action = function()
			require("tiny-code-action").code_action()
		end,
		desc = "Code action",
		method = "textDocument/codeAction",
	},
	{
		key = "<leader>lf",
		action = function()
			vim.lsp.buf.format({ async = true, name = "efm" })
		end,
		desc = "Format",
		method = "textDocument/formatting",
	},
	{ key = "<leader>ll", action = function()
    vim.lsp.codelens.refresh()
    vim.lsp.codelens.run()
  end, desc = "Run CodeLens", method = "textDocument/codeLens" },
	{
		key = "gl",
		action = function()
			vim.diagnostic.open_float({ border = "rounded" })
		end,
		desc = "Line diagnostics",
	},
	-- { key = "[d", action = vim.diagnostic.goto_prev, desc = "Previous diagnostic" },
	{ key = "]d", action = function() vim.diagnostic.jump({ count = 1, float = true }) end, desc = "Next diagnostic" },
	{ key = "<leader>lE", action = vim.diagnostic.setloclist, desc = "Diagnostic loclist" },
}

M.base_visual = {
	-- { key = "<leader>la", action = vim.lsp.buf.code_action, desc = "Code action", method = "textDocument/codeAction" },
}

M.per_server = {
	gopls = {
		{
			key = "<leader>li",
			action = function()
				require("user.lsp.actions").gopls_organize_imports(vim.api.nvim_get_current_buf())
			end,
			desc = "Organize imports",
		},
	},
	vtsls = {
		{
			key = "<leader>li",
			action = function()
				require("user.lsp.actions").ts_organize_imports(vim.api.nvim_get_current_buf())
			end,
			desc = "Organize imports",
		},
	},
}

M.whichkey_groups = {
	normal = {
		{ "<leader>l", group = "LSP" },
	},
	visual = {
		{ "<leader>l", group = "LSP" },
	},
}

return M
