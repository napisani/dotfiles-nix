local capabilities = vim.lsp.protocol.make_client_capabilities()
-- Enable inlay hint capability
capabilities.textDocument = capabilities.textDocument or {}
capabilities.textDocument.inlayHint = {
	dynamicRegistration = false,
	resolveSupport = {
		properties = { "tooltip", "textEdits", "label.tooltip", "label.location", "label.command" },
	},
}

return {
	root_markers = { ".git" },
	cmd = {
		"npx",
		"node",
		"/Users/nick/code/learn-lsp/server/out/server.js",
		"--stdio",
	},
	capabilities = capabilities,
	-- Add on_attach to enable inlay hints when the server attaches
	on_attach = function(client, bufnr)
		-- Only enable inlay hints for learnls, not other LSPs on the same buffer
		if client.name == "learnls" and client.server_capabilities.inlayHintProvider then
			vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })

			-- Ensure other LSPs don't interfere when they attach
			vim.api.nvim_create_autocmd("LspAttach", {
				buffer = bufnr,
				callback = function(args)
					local other_client = vim.lsp.get_client_by_id(args.data.client_id)
					if other_client and other_client.name ~= "learnls" then
						-- Re-enable after other LSP attaches to maintain learnls hints
						vim.defer_fn(function()
							vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
						end, 100)
					end
				end,
			})
		end
	end,
}
