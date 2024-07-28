local nvim_lsp = require("lspconfig")

return {
	root_dir = nvim_lsp.util.root_pattern("deno.json", "deno.jsonc"),
	settings = {
		deno = {
			inlayHints = {
				parameterNames = { enabled = "all", suppressWhenArgumentMatchesName = true },
				parameterTypes = { enabled = true },
				variableTypes = { enabled = true, suppressWhenTypeMatchesName = true },
				propertyDeclarationTypes = { enabled = true },
				functionLikeReturnTypes = { enable = true },
				enumMemberValues = { enabled = true },
			},
		},
	},
}
