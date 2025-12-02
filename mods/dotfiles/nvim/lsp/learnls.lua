local capabilities = vim.lsp.protocol.make_client_capabilities()
-- Enable inlay hint capability
capabilities.inlayHint = { dynamicRegistration = false }

return {
	root_markers = { ".git" },
	cmd = {
		"npx",
		"ts-node",
		"/Users/nick/code/learn-lsp/server/out/server.js",
		"--stdio",
	},
	capabilities = capabilities,
	-- Add on_attach to enable inlay hints when the server attaches
	on_attach = function(client, bufnr)
		if client.server_capabilities.inlayHintProvider then
			vim.lsp.inlay_hint.enable(true)
		end
	end,
}
