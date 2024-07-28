function fix_all_imports(bufnr, timeout_ms)
	local params = vim.lsp.util.make_range_params()
	params.context = { only = { "source.organizeImports" } }
	local result = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, timeout_ms)
	for _, res in pairs(result or {}) do
		for _, r in pairs(res.result or {}) do
			if r.edit then
				vim.lsp.util.apply_workspace_edit(r.edit, "utf-8")
			else
				vim.lsp.buf.execute_command(r.command)
			end
		end
	end
end

return {
	-- settings = {
	-- 	hints = {
	-- 		rangeVariableTypes = true,
	-- 		parameterNames = true,
	-- 		constantValues = true,
	-- 		assignVariableTypes = true,
	-- 		compositeLiteralFields = true,
	-- 		compositeLiteralTypes = true,
	-- 		functionTypeParameters = true,
	-- 	},
	-- },

	server = {
		on_attach = function(_client, bufnr)
			local opts = {
				noremap = true,
				silent = true,
				callback = function()
					fix_all_imports(bufnr, 4000)
				end,
			}
			vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>li", "", opts)
		end,
	},
}
