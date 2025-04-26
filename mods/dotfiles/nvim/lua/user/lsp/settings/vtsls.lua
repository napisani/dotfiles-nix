local vtsls = require("vtsls")
local nvim_lsp = require("lspconfig")

local fix_all_imports = function(bufnr)
	if not bufnr then
		bufnr = vim.api.nvim_get_current_buf()
	end

	vtsls.commands.add_missing_imports(bufnr)
	vtsls.commands.remove_unused_imports(bufnr)
	vtsls.commands.organize_imports(bufnr)
end

return {
	-- in single file mode the root_dir is ignored, so this needs to be false
	single_file_support = false,
	root_dir = nvim_lsp.util.root_pattern("package.json"),
	settings = {
		typescript = {
			inlayHints = {
				parameterNames = { enabled = "all" },
				parameterTypes = { enabled = true },
				variableTypes = { enabled = true },
				propertyDeclarationTypes = { enabled = true },
				functionLikeReturnTypes = { enabled = true },
				enumMemberValues = { enabled = true },
			},
		},
	},
	server = {

		on_attach = function(_client, bufnr)
			local opts = {
				noremap = true,
				silent = true,
				callback = function()
					fix_all_imports(bufnr)
				end,
			}
			vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>li", "", opts)
		end,

		fix_all_imports = fix_all_imports,
	},
}
