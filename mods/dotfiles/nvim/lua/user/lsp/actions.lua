local M = {}

function M.ts_organize_imports(bufnr)
	vim.lsp.buf.code_action({
		apply = true,
		context = { only = { "source.addMissingImports.ts" }, diagnostics = {} },
	})
	vim.lsp.buf.code_action({
		apply = true,
		context = { only = { "source.removeUnusedImports.ts" }, diagnostics = {} },
	})
end

function M.gopls_organize_imports(bufnr, timeout_ms)
	timeout_ms = timeout_ms or 4000
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

return M
