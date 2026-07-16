local cmd = { "vtsls", "--stdio" }
if vim.fn.has("win32") == 1 then
	cmd = { "cmd.exe", "/C", unpack(cmd) }
end

-- tsserver has been aborting with SIGABRT (V8 FatalProcessOutOfMemory).
-- Diagnostic reports showed ~21k live fs_event/fs_poll watchers (one per
-- project file) on the loancrate monorepo at crash time -- see the
-- watchOptions fix below. Keep report-on-fatalerror on in case it recurs.
local tsserver_report_dir = vim.fn.stdpath("state") .. "/tsserver-reports"
vim.fn.mkdir(tsserver_report_dir, "p")
local cmd_env = {
	NODE_OPTIONS = "--report-on-fatalerror --report-directory=" .. tsserver_report_dir,
}

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
	cmd_env = cmd_env,
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

	root_markers = {
		"package-lock.json",
		"yarn.lock",
		"pnpm-lock.yaml",
		".git",
	},
	workspace_required = true,

	single_file_support = false,
	settings = {
		complete_function_calls = true,
		typescript = {
			updateImportsOnFileMove = "always",
			tsserver = {
				maxTsServerMemory = 8192,
				-- Default per-file watching hit ~21k live watchers on this
				-- monorepo and crashed tsserver. Watch parent directories
				-- instead (Microsoft's recommended setting for large repos).
				watchOptions = {
					watchFile = "useFsEventsOnParentDirectory",
				},
			},
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
			autoUseWorkspaceTsdk = true,
			experimental = {
				completion = {
					enableServerSideFuzzyMatch = true,
				},
			},
		},
	},
}
