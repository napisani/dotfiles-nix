local vtsls = require("vtsls")

local fix_all_imports = function(bufnr)
	-- vim.lsp.buf.code_action({ apply = true, context = { only = { "source.addMissingImports.ts" } } })
	-- vim.lsp.buf.code_action({ apply = true, context = { only = { "source.removeUnusedImports.ts" } } })
	vtsls.commands.add_missing_imports(bufnr)
	vtsls.commands.remove_unused_imports(bufnr)
	vtsls.commands.organize_imports(bufnr)
end

return {
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
	},

}
