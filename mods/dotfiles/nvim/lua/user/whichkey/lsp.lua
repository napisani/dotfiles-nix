local normal_mappings = {
	{ "<leader>l", group = "LSP" },
	{ "<leader>lc", "<Plug>ContextCommentaryLine", desc = "(c)omment" },
}

local visual_mappings = {
	{ "<leader>l", group = "LSP" },
	{ "<leader>lc", "<Plug>ContextCommentary", desc = "(c)omment" },
}

local shared_mapping = {
	{ "<leader>lR", "<cmd>:LspRestart<cr>", desc = "(R)estart LSPs" },
	-- { "<leader>lS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", desc = "workspace (S)ymbols" },
	-- { "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>", desc = "Code (a)ction" },
	{ "<leader>la", "<cmd>lua require('tiny-code-action').code_action()<cr>", desc = "Code (a)ction" },
	-- { "<leader>ld", "<cmd>Telescope lsp_document_diagnostics<cr>", desc = "(d)ocument diagnostics" },
	{ "<leader>lf", "<cmd>lua vim.lsp.buf.format{ async=true, name = 'efm' }<cr>", desc = "(f)ormat" },
	{ "<leader>li", desc = "organize (i)mports" },
	{ "<leader>lj", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", desc = "Next Diagnostic" },
	{ "<leader>lk", "<cmd>lua vim.lsp.diagnostic.goto_prev()<cr>", desc = "Prev Diagnostic" },
	{ "<leader>ll", "<cmd>lua vim.lsp.codelens.run()<cr>", desc = "Codea(l)ens Action" },
	{ "<leader>lq", "<cmd>lua vim.lsp.diagnostic.set_loclist()<cr>", desc = "(q)uickfix" },
	{ "<leader>lr", "<cmd>lua vim.lsp.buf.rename()<cr>", desc = "(r)ename" },
	-- { "<leader>ls", "<cmd>Telescope lsp_document_symbols<cr>", desc = "document (s)ymbols" },
	-- { "<leader>lw", "<cmd>Telescope lsp_workspace_diagnostics<cr>", desc = "(w)orkspace diagnostics" },
}

for _, mapping in ipairs(shared_mapping) do
	table.insert(normal_mappings, mapping)
	table.insert(visual_mappings, mapping)
end

return {
	mapping_v = visual_mappings,
	mapping_n = normal_mappings,
	mapping_shared = {},
}
