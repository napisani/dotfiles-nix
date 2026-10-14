-- Buffer LSP maps applied on attach. Neovim 0.11+ also defines stock `g*` maps (e.g. `grn` rename,
-- `gra` code action, `grr` references); see `:h lsp-defaults`. These `<leader>l*` / `gr` maps stay as
-- the primary discoverable bindings (which-key, tiny-code-action for `la`).
local M = {}

local function location_opts(filter_scope, jump_single)
	-- Capture the source before the asynchronous LSP response changes focus.
	local source_tab = vim.api.nvim_get_current_tabpage()
	return {
		on_list = function(list_ctx)
			if filter_scope then
				local path = require("user.scope.path")
				local category = require("user.scope.category")
				list_ctx.items = vim.tbl_filter(function(item)
					return path.is_visible(item.filename) and category.is_visible(item.filename)
				end, list_ctx.items)
			end
			if #list_ctx.items == 0 then
				vim.notify("No locations in the active scope", vim.log.levels.INFO)
				return
			end
			require("user.utils.edit_navigation").focus_editing_win(source_tab)
			vim.fn.setloclist(0, {}, " ", list_ctx)
			if jump_single and #list_ctx.items == 1 then
				vim.cmd.lfirst()
				vim.cmd("normal! zv")
			else
				vim.cmd.lopen()
			end
		end,
	}
end

local function goto_location(name)
	return function()
		local lib = package.loaded["diffview.lib"]
		local opts = lib and lib.get_current_view() and location_opts(false, true) or nil
		vim.lsp.buf[name](opts)
	end
end

M.base = {
	{ key = "gd", action = goto_location("definition"), desc = "Go to definition", method = "textDocument/definition" },
	{
		key = "gD",
		action = goto_location("declaration"),
		desc = "Go to declaration",
		method = "textDocument/declaration",
	},
	{
		key = "gy",
		action = goto_location("type_definition"),
		desc = "Go to type definition",
		method = "textDocument/typeDefinition",
	},
	{ key = "K", action = vim.lsp.buf.hover, desc = "Hover", method = "textDocument/hover" },
	{
		key = "gO",
		action = vim.lsp.buf.document_symbol,
		desc = "Document symbols",
		method = "textDocument/documentSymbol",
	},
	{
		key = "gi",
		action = function()
			vim.lsp.buf.implementation(location_opts(true, false))
		end,
		desc = "Go to implementation",
		method = "textDocument/implementation",
	},
	{
		key = "gr",
		action = function()
			vim.lsp.buf.references(nil, location_opts(true, false))
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
	{
		key = "<leader>ll",
		action = function()
			vim.lsp.codelens.refresh()
			vim.lsp.codelens.run()
		end,
		desc = "Run CodeLens",
		method = "textDocument/codeLens",
	},
	{
		key = "gl",
		action = function()
			vim.diagnostic.open_float({ border = "rounded" })
		end,
		desc = "Line diagnostics",
	},
	-- { key = "[d", action = vim.diagnostic.goto_prev, desc = "Previous diagnostic" },
	{
		key = "]d",
		action = function()
			vim.diagnostic.jump({ count = 1, float = true })
		end,
		desc = "Next diagnostic",
	},
	{ key = "<leader>lE", action = vim.diagnostic.setloclist, desc = "Diagnostic loclist" },
}

-- Stock Neovim goto bindings must use the same destination policy.
for alias, key in pairs({ gri = "gi", grr = "gr", grt = "gy", grn = "<leader>lr", gra = "<leader>la" }) do
	for _, mapping in ipairs(M.base) do
		if mapping.key == key then
			local copy = vim.tbl_extend("force", mapping, { key = alias })
			table.insert(M.base, copy)
			break
		end
	end
end

M.base_visual = {
	{ key = "gra", action = vim.lsp.buf.code_action, desc = "Code action", method = "textDocument/codeAction" },
}

M.base_insert = {
	{
		key = "<C-s>",
		action = vim.lsp.buf.signature_help,
		desc = "Signature help",
		method = "textDocument/signatureHelp",
	},
}

M.per_server = {
	gopls = {
		{
			key = "<leader>li",
			action = function()
				require("user.lsp.actions").gopls_organize_imports(vim.api.nvim_get_current_buf())
			end,
			method = "textDocument/codeAction",
			desc = "Organize imports",
		},
	},
	vtsls = {
		{
			key = "<leader>li",
			action = function()
				require("user.lsp.actions").ts_organize_imports(vim.api.nvim_get_current_buf())
			end,
			method = "textDocument/codeAction",
			desc = "Organize imports",
		},
	},
}

local lists = { M.base, M.base_visual, M.base_insert }
for _, mappings in pairs(M.per_server) do
	table.insert(lists, mappings)
end
for _, mappings in ipairs(lists) do
	for _, mapping in ipairs(mappings) do
		if mapping.method then
			local action = mapping.action
			mapping.action = function()
				return require("user.lsp.lifecycle").request(mapping.method, action)
			end
		end
	end
end

M.whichkey_groups = {
	normal = {
		{ "<leader>l", group = "LSP" },
	},
	visual = {
		{ "<leader>l", group = "LSP" },
	},
}

return M
