local function typescript_organize_imports()
	local params = {
		command = "_typescript.organizeImports",
		arguments = { vim.api.nvim_buf_get_name(0) },
	}
	vim.lsp.buf.execute_command(params)
end

return {
  -- filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue", "json", "typescript.tsx" },
  -- cmd = { "typescript-language-server", "--stdio" },
  -- cmd = { "bun", "x", "typescript-language-server", "--stdio" },
  completions = {
    completeFunctionCalls = true,
  },
  commands = {
    OrganizeImports = {
      typescript_organize_imports,
      description = "Organize Imports",
    },
  }
}
