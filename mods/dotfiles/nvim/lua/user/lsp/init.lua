require("user.lsp.mason")
require("mason-nvim-dap").setup({
	lazy = false,
	ensure_installed = { "python", "lldb", "chrome", "js", "delve" },
})

require("user.lsp.attach").setup()

local inline_group = vim.api.nvim_create_augroup("user_lsp_inline_completion", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
	group = inline_group,
	callback = function(args)
		local client_id = args.data and args.data.client_id
		if not client_id then
			return
		end
		local client = vim.lsp.get_client_by_id(client_id)
		if not client then
			return
		end
		local inline = vim.lsp.inline_completion
		if not inline or type(inline.enable) ~= "function" then
			return
		end
		if client.supports_method and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, args.buf) then
			inline.enable(true, { bufnr = args.buf })
		end
	end,
})

vim.lsp.config("eslint", {
	single_file_support = true,
	settings = {
		packageManager = "yarn", -- or 'npm'
	},
})

	vim.lsp.enable({
		"efm",
		"gopls",
		"jsonls",
		"lua_ls",
		"cssls",
		"bashls",
		-- "pyright",
		"basedpyright",
		"ruff",
		"yamlls",
		"expert",
		-- "learnls",
	})

vim.lsp.enable("copilot")

local function get_learnls_client(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		if client.name == "learnls" or client.name == "learn-ls" then
			return client
		end
		if client.server_info and client.server_info.name == "learn-ls" then
			return client
		end
	end
end

local function open_rag_float(result)
	if not result then
		vim.notify("No result returned from learnls", vim.log.levels.WARN)
		return
	end

	local content = result.content or vim.inspect(result)
	local format = result.format or "text"

	local lines = vim.split(content, "\n", { plain = true })
	local ft = (format == "markdown") and "markdown" or "text"

	vim.lsp.util.open_floating_preview(lines, ft, {
		border = "rounded",
		max_width = math.floor(vim.o.columns * 0.8),
		max_height = math.floor(vim.o.lines * 0.6),
		wrap = true,
	})
end

local function learnls_rag_float()
	local bufnr = vim.api.nvim_get_current_buf()
	local client = get_learnls_client(bufnr)
	if not client then
		vim.notify("learnls client not attached", vim.log.levels.WARN)
		return
	end

	local uri = vim.uri_from_bufnr(bufnr)
	local mode = vim.fn.mode()
	local is_visual = mode == "v" or mode == "V" or mode == "\22"

	local args = {
		uri = uri,
		showInMessage = false, -- important: avoids message-area spam
		format = "markdown", -- server returns markdown for the float
	}

	if is_visual then
		local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<")
		local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")
		local srow, scol = start_pos[1] - 1, start_pos[2]
		local erow, ecol = end_pos[1] - 1, end_pos[2]
		if (erow < srow) or (erow == srow and ecol < scol) then
			srow, erow = erow, srow
			scol, ecol = ecol, scol
		end

		local sel_lines = vim.api.nvim_buf_get_text(bufnr, srow, scol, erow, ecol + 1, {})
		args.selectionText = table.concat(sel_lines, "\n")

		-- exit visual mode
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
	else
		args.line = vim.api.nvim_win_get_cursor(0)[1] - 1
	end

	client.request("workspace/executeCommand", {
		command = "learnls.showRagContext",
		arguments = { args },
	}, function(err, res)
		if err then
			vim.notify("learnls executeCommand failed: " .. (err.message or vim.inspect(err)), vim.log.levels.ERROR)
			return
		end
		open_rag_float(res)
	end, bufnr)
end

vim.keymap.set({ "n", "x" }, "<leader>2", learnls_rag_float, { desc = "learnls: RAG float (line/selection)" })

-- For now, i need to completely disable vtsls for any projects that are
-- using deno, to avoid conflicts.
-- for some reason, the root_dir function and root_markers config options
-- are not working as expected for vtsls.
local is_deno = vim.fs.root(0, { "deno.json", "deno.jsonc" })

if is_deno then
	vim.lsp.enable({ "denols" })
else
	vim.lsp.enable({ "vtsls" })
end

vim.diagnostic.config({
	virtual_lines = false,
	virtual_text = false,

	underline = true,
	update_in_insert = true,
	severity_sort = true,
	float = {
		border = "rounded",
		source = true,
	},
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "󰅚 ",
			[vim.diagnostic.severity.WARN] = "󰀪 ",
			[vim.diagnostic.severity.INFO] = "󰋽 ",
			[vim.diagnostic.severity.HINT] = "󰌶 ",
		},
		numhl = {
			[vim.diagnostic.severity.ERROR] = "ErrorMsg",
			[vim.diagnostic.severity.WARN] = "WarningMsg",
		},
	},
})

vim.lsp.config("*", {
	root_markers = { ".git" },
})

vim.cmd([[ command! Format execute 'lua vim.lsp.buf.format{async=true}' ]])
