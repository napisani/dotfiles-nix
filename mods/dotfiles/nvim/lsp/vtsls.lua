local cmd = { "vtsls", "--stdio" }
if vim.fn.has("win32") == 1 then
	cmd = { "cmd.exe", "/C", unpack(cmd) }
end

local source_action_kinds = {
	organize_imports = "source.organizeImports",
	sort_imports = "source.sortImports",
	remove_unused_imports = "source.removeUnusedImports",
	fix_all = "source.fixAll.ts",
	remove_unused = "source.removeUnused.ts",
	add_missing_imports = "source.addMissingImports.ts",
}

local action_table = setmetatable({}, {
	---@param action lsp.CodeActionKind Actions not of this kind are filtered out by the client before being shown
	---@return function
	__index = function(_, action)
		return function()
			vim.lsp.buf.code_action({
				apply = true,
				context = {
					only = { action },
					diagnostics = {},
				},
			})
		end
	end,
})

return {
	cmd = cmd,
	init_options = {
		hostInfo = "neovim",
	},
	filetypes = {
		"javascript",
		"javascriptreact",
		"javascript.jsx",
		"typescript",
		"typescriptreact",
		"typescript.tsx",
	},

	root_markers = { "package-lock.json", "yarn.lock", "pnpm-lock.yaml" },
	workspace_required = true,

	single_file_support = false,
	settings = {
		typescript = {
			updateImportsOnFileMove = "always",
			inlayHints = {
				parameterNames = { enabled = "all" },
				parameterTypes = { enabled = true },
				variableTypes = { enabled = true },
				propertyDeclarationTypes = { enabled = true },
				functionLikeReturnTypes = { enabled = true },
				enumMemberValues = { enabled = true },
			},
		},
		javascript = {
			updateImportsOnFileMove = "always",
		},
		vtsls = {
			enableMoveToFileCodeAction = true,
		},
	},
	on_attach = function(client, bufnr)
		vim.keymap.set("n", "<leader>li", function()
			-- local params = {
			-- 	command = source_action_kinds.add_missing_imports,
			-- 	arguments = { vim.api.nvim_buf_get_name(0) },
			-- }
			-- client.request("workspace/executeCommand", params, nil, bufnr)
			vim.lsp.buf.code_action({
				apply = true,
				context = { only = { "source.addMissingImports.ts" }, diagnostics = {} },
			})
			vim.lsp.buf.code_action({
				apply = true,
				context = { only = { "source.removeUnusedImports.ts" }, diagnostics = {} },
			})
		end, { buffer = bufnr, desc = "Add missing imports" })
	end,
}
