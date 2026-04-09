-- Native LSP config for copilot-language-server (Neovim 0.11+ vim.lsp.config style)
-- Installed via mason: copilot-language-server
return {
	cmd = { "copilot-language-server", "--stdio" },
	root_markers = { ".git" },
	-- nil means attach to ALL filetypes (per vim.lsp.config docs)
	init_options = {
		editorInfo = {
			name = "Neovim",
			version = tostring(vim.version()),
		},
		editorPluginInfo = {
			name = "Neovim",
			version = tostring(vim.version()),
		},
	},
}
