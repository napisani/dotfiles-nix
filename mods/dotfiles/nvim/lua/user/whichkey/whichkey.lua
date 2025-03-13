local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
	return
end
local utils = require("user.utils")
local replace_mapping = require("user.whichkey.replace")
local find_mapping = require("user.whichkey.find_snacks")
local search_mapping = require("user.whichkey.search_snacks")
local ai_mapping = require("user.whichkey.ai")
local Snacks = require("snacks")
local git = require("user.whichkey.git")
local changes = require("user.whichkey.changes")

local root_mapping = {
	{ '<leader>"', "<cmd>:split<cr>", desc = "Horizontal Split" },
	{ "<leader>%", "<cmd>:vsplit<cr>", desc = "Vertical Split" },
	{ "<leader>-", "<cmd>:Oil<cr>", desc = "(O)il" },
	{
		"<leader>e",
		function()
			require("user.snacks.find_files").toggle_explorer_tree()
		end,
		desc = "Explorer",
	},
	{ "<leader><leader>e", "<cmd>:aboveleft Outline<cr>", desc = "outlin(e)" },
	{ "<leader>q", "<cmd>q!<CR>", desc = "Quit" },
	-- { "<leader>K", "<cmd>:LegendaryRepeat<CR>", desc = "Repeat last (K)command" },
	-- { "<leader>lc", "<Plug>ContextCommentaryLine", desc = "(c)omment" },
}

local database = {
	{ "<leader>D", group = "Database" },
	{ "<leader>Do", "<Cmd>DBUI<CR>", desc = "(o)pen" },
	{ "<leader>Dq", "<Cmd>DBUIClose<CR>", desc = "(q)uit" },
	{ "<leader>DW", "<plug>(DBUI_SaveQuery)", desc = "Save Query" },
	{ "<leader>Dr", "DBUIRenameBuffer", desc = "Rename Buffer" },
}

local lazy_system = {
	{ "<leader>P", group = "Lazy/System" },
	{ "<leader>Pm", "<cmd>Mason<cr>", desc = "(m)ason" },
	{ "<leader>Ps", "<cmd>Lazy<cr>", desc = "(s)ync packages" },
	{ "<leader>Pt", "<cmd>TSUpdate<cr>", desc = "(t)reesitter update" },
}

local quit = {
	{ "<leader>Q", "<Cmd>:q<CR>", desc = "(Q)uit" },
	{ "<leader>w", "<cmd>w!<CR>", desc = "(w)rite" },
	{
		"<leader>x",
		function()
			Snacks.bufdelete()
		end,
		desc = "Close Buffer",
	},
}

local repl = {
	{ "<leader>R", group = "REPL" },
	{ "<leader>Rc", desc = "send motion / visual send" },
	{ "<leader>Rf", desc = "send (f)ile" },
	{ "<leader>Rl", desc = "send (l)ine" },
	{ "<leader>Rmc", desc = "mark motion/visual" },
	{ "<leader>Rmd", desc = "(d)elete mark" },
	{ "<leader>Ro", "<cmd>:IronRepl<cr>", desc = "(O)pen REPL" },
	{ "<leader>Rq", desc = "(q)uit repl" },
	{ "<leader>Rx", desc = "clear repl" },
}

local write_all = {
	{ "<leader>W", "<cmd>:wa<cr>", desc = "(w)rite all" },
}

local buffers = {
	{ "<leader>b", group = "buffers" },
	{
		"<leader>bo",
		function()
			Snacks.bufdelete.other()
		end,
		desc = "(o)nly keep current Buffer",
	},

	{
		"<leader>bq",
		function()
			Snacks.bufdelete()
		end,
		desc = "(q)uit Buffer",
	},

	{
		"<leader>bfy",
		function()
			-- Get the full path of the current buffer
			local buffer_path = vim.api.nvim_buf_get_name(0)
			if buffer_path == "" then
				return
			end
			local file_name = vim.fn.fnamemodify(buffer_path, ":t")
			vim.fn.setreg("+", file_name)
		end,
		desc = "(y)ank path",
	},
	{
		"<leader>bpy",
		function()
			local buffer_path = vim.api.nvim_buf_get_name(0)
			vim.fn.setreg("+", buffer_path)
		end,
		desc = "(y)ank filename",
	},
}

local overseer = {
	{ "<leader>o", group = "Overseer" },
	{ "<leader>oo", "<cmd>:OverseerOpen<CR>", desc = "(O)pen" },
	{ "<leader>oq", "<cmd>:OverseerClose<CR>", desc = "(q)uit" },
}

local debugging = {
	{ "<leader>d", group = "Debug" },
	{
		"<leader>dB",
		"<Cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>",
		desc = "conditional breakpoint",
	},
	{
		"<leader>dL",
		"<Cmd>lua require'dap'.set_breakpoint(vim.fn.input(nil, nil, vim.fn.input('Log point message: ')))<CR>",
		desc = "log point",
	},
	{ "<leader>dX", "<Cmd>lua require'dap'.clear_breakpoints()<CR>", desc = "Clear all Breakpoints" },
	{ "<leader>db", "<Cmd>lua require'dap'.toggle_breakpoint()<CR>", desc = "toggle breakpoint" },
	{ "<leader>dc", "<Cmd>lua require'dap'.continue()<CR>", desc = "continue/launch" },
	{ "<leader>dh", "<Cmd>lua require'dap'.step_into()<CR>", desc = "step_into" },
	{ "<leader>dj", "<Cmd>lua require'dap'.step_over()<CR>", desc = "step over" },
	{ "<leader>dk", "<Cmd>lua require'dap'.step_out()<CR>", desc = "step out" },
	{ "<leader>dl", "<Cmd>lua require'dap'.run_last()<CR>", desc = "run last" },
	{ "<leader>do", "<Cmd>lua require'dapui'.open()<CR>", desc = "open debugger" },
	{ "<leader>dq", "<Cmd>lua require'dapui'.close()<CR>", desc = "close debugger" },
	{ "<leader>dr", "<Cmd>lua require'dap'.repl.open()<CR>", desc = "open REPL" },
}

local lsp = {
	{ "<leader>l", group = "LSP" },
	{ "<leader>lR", "<cmd>:LspRestart<cr>", desc = "(R)estart LSPs" },
	-- { "<leader>lS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", desc = "workspace (S)ymbols" },
	-- { "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>", desc = "Code (a)ction" },
	{ "<leader>la", "<cmd>lua require('tiny-code-action').code_action()<cr>", desc = "Code (a)ction" },
	-- { "<leader>ld", "<cmd>Telescope lsp_document_diagnostics<cr>", desc = "(d)ocument diagnostics" },
	{ "<leader>lf", "<cmd>lua vim.lsp.buf.format{ async=true, name = 'efm' }<cr>", desc = "(f)ormat" },
	{ "<leader>li", desc = "organize (i)mports" },
	{ "<leader>lj", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", desc = "Next Diagnostic" },
	{ "<leader>lk", "<cmd>lua vim.lsp.diagnostic.goto_prev()<cr>", desc = "Prev Diagnostic" },
	{ "<leader>lh", "<cmd>lua require('user.lsp.handlers').toggle_inlay_hints()<cr>", desc = "inlay (h)ints" },
	{ "<leader>ll", "<cmd>lua vim.lsp.codelens.run()<cr>", desc = "Codea(l)ens Action" },
	{ "<leader>lq", "<cmd>lua vim.lsp.diagnostic.set_loclist()<cr>", desc = "(q)uickfix" },
	{ "<leader>lr", "<cmd>lua vim.lsp.buf.rename()<cr>", desc = "(r)ename" },
	-- { "<leader>ls", "<cmd>Telescope lsp_document_symbols<cr>", desc = "document (s)ymbols" },
	-- { "<leader>lw", "<cmd>Telescope lsp_workspace_diagnostics<cr>", desc = "(w)orkspace diagnostics" },
}

local mapping_n = utils.extend_lists(
	find_mapping.mapping_n,
	search_mapping.mapping_n,
	ai_mapping.mapping_n,
	replace_mapping.mapping_n,
	git.mapping_n,
	changes.mapping_n,
	{
		{ "<leader>lc", "<Plug>ContextCommentaryLine", desc = "(c)omment" },
	}
)

local mapping_v = {
	mode = { "v" },
	utils.extend_lists(find_mapping.mapping_v, search_mapping.mapping_v, {
		{ "<leader>lc", "<Plug>ContextCommentary", desc = "(c)omment" },
	}, git.mapping_v, changes.mapping_v, ai_mapping.mapping_v, replace_mapping.mapping_v),
}

-- Register mapping
which_key.setup({})

local shared_mapping = {
	root_mapping,
	database,
	lazy_system,
	quit,
	repl,
	write_all,
	buffers,
	overseer,
	debugging,
	git.mapping_shared,
	changes.mapping_shared,
	lsp,
}

for _, mapping in ipairs(shared_mapping) do
	for _, mapping in ipairs(mapping) do
		table.insert(mapping_n, mapping)
		table.insert(mapping_v, mapping)
	end
end

which_key.add(mapping_n)
which_key.add(mapping_v)

return {
	mapping_n = mapping_n,
	mapping_v = mapping_v,
}

-- which_key.register(mapping_v, opts_v)
