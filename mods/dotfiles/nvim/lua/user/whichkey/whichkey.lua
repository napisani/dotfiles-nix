local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
	return
end
local utils = require("user.utils")
local primary_branch = utils.get_primary_git_branch()
local prod_branch = utils.get_prod_git_branch()
local replace_mapping = require("user.whichkey.replace")
local find_mapping = require("user.whichkey.find_snacks")
local search_mapping = require("user.whichkey.search_snacks")
local ai_mapping = require("user.whichkey.ai")

-- Shared mapping
-- local surround = {
-- 	{ "<leader>s", group = "Surround" },
-- 	{ "<leader>sa", desc = "Add surrounding in Normal and Visual modes" },
-- 	{ "<leader>sd", desc = "Delete surrounding" },
-- 	{ "<leader>sf", desc = "Find surrounding (to the right)" },
-- 	{ "<leader>sF", desc = "Find surrounding (to the left)" },
-- 	{ "<leader>sh", desc = "Highlight surrounding" },
-- 	{ "<leader>sr", desc = "Replace surrounding" },
-- 	{ "<leader>sn", desc = "Update `n_lines`" },
-- 	{ "<leader>sl", desc = "Suffix to search with 'prev' method" },
-- 	{ "<leader>sn", desc = "Suffix to search with 'next' method" },
-- }

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
	{ "<leader>K", "<cmd>:LegendaryRepeat<CR>", desc = "Repeat last (K)command" },
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
	{ "<leader>x", "<cmd>Bdelete!<CR>", desc = "Close Buffer" },
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

local alpha = {
	{ "<leader>A", "<cmd>Alpha<cr>", desc = "Alpha" },
}

local buffers = {
	{ "<leader>b", group = "buffers" },
	{
		"<leader>bo",
		"<cmd>lua require('user.utils').close_all_buffers_except_current()<CR>",
		desc = "(o)nly keep current Buffer",
	},
	{ "<leader>bq", "<cmd>Bdelete!<CR>", desc = "(q)uit Buffer" },

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

local changes = {
	{ "<leader>c", group = "Changes" },
	{ "<leader>cB", "<Cmd>:G blame<CR>", desc = "Blame" },
	{ "<leader>cH", "<Cmd>:DiffviewOpen HEAD<CR>", desc = "diff (H)ead" },
	{ "<leader>ch", "<Cmd>:DiffViewFileHistory<CR>", desc = "(h)istory" },
	{ "<leader>cM", "<Cmd>:DiffviewOpen origin/" .. primary_branch .. "<CR>", desc = "origin/" .. primary_branch },
	{ "<leader>cP", "<Cmd>:DiffviewOpen origin/" .. prod_branch .. "<CR>", desc = "origin/" .. prod_branch },
	{ "<leader>cm", "<Cmd>:DiffviewOpen " .. primary_branch .. "<CR>", desc = primary_branch },
	{ "<leader>cp", "<Cmd>:DiffviewOpen " .. prod_branch .. "<CR>", desc = prod_branch },
	{ "<leader>co", "<Cmd>:DiffviewOpen<CR>", desc = "Open" },
	{ "<leader>cq", "<Cmd>:DiffviewClose<CR>", desc = "DiffviewClose" },
	{ "<leader>cx", '<Cmd>call feedkeys("dx")<CR>', desc = "Choose DELETE" },

	{ "<leader>cf", group = "(F)ile" },
	{ "<leader>cfH", "<Cmd>:DiffviewOpen HEAD -- %<CR>", desc = "diff (H)ead" },
	{ "<leader>cfM", "<Cmd>:DiffviewOpen " .. primary_branch .. " -- %<CR>", desc = "origin/" .. primary_branch },
	{ "<leader>cfP", "<Cmd>:DiffviewOpen " .. prod_branch .. " -- %<CR>", desc = "origin/" .. prod_branch },
	{ "<leader>cff", "<cmd>lua require('user.telescope').find_file_from_root_to_compare_to()<CR>", desc = "(f)ile" },
	{ "<leader>cfh", "<Cmd>:DiffviewFileHistory --follow %<CR>", desc = "(h)istory" },
	{ "<leader>cfm", "<Cmd>:DiffviewOpen " .. primary_branch .. " -- %<CR>", desc = primary_branch },
	{ "<leader>cfp", "<Cmd>:DiffviewOpen " .. prod_branch .. " -- %<CR>", desc = prod_branch },

	-- changes
	{ "<leader>cfc", "<cmd>CompareClipboard<cr>", desc = "compare (c)lipboard" },
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

local git = {
	{ "<leader>g", group = "Git" },
	{ "<leader>gC", "<cmd>Telescope git_commits<cr>", desc = "Checkout commit" },
	{ "<leader>gP", "<cmd>lua require 'gitsigns'.preview_hunk()<cr>", desc = "Preview Hunk" },
	{ "<leader>gR", "<cmd>lua require 'gitsigns'.reset_buffer()<cr>", desc = "Reset Buffer" },
	{ "<leader>gb", "<cmd>Telescope git_branches<cr>", desc = "Checkout branch" },
	{ "<leader>gc", group = "Checkout" },
	{ "<leader>gcM", "<Cmd>:G checkout " .. primary_branch .. " -- %<CR>", desc = "origin/(M)ain" },
	{ "<leader>gcP", "<Cmd>:G checkout " .. prod_branch .. " -- %<CR>", desc = "origin/(P)rod" },
	{ "<leader>gch", "<Cmd>:G checkout HEAD -- %<CR>", desc = "HEAD" },
	{ "<leader>gcm", "<Cmd>:G checkout " .. primary_branch .. " -- %<CR>", desc = "(m)ain" },
	{ "<leader>gcp", "<Cmd>:G checkout " .. prod_branch .. " -- %<CR>", desc = "(p)rod" },
	{ "<leader>gl", "<cmd>lua require 'gitsigns'.blame_line()<cr>", desc = "Blame" },
	{ "<leader>gn", "<cmd>lua require 'gitsigns'.next_hunk()<cr>", desc = "Next Hunk" },
	{ "<leader>go", "<Cmd>:Neogit<CR>", desc = "Open neogit" },
	{ "<leader>gp", "<cmd>lua require 'gitsigns'.prev_hunk()<cr>", desc = "Prev Hunk" },
	{ "<leader>gr", "<cmd>lua require 'gitsigns'.reset_hunk()<cr>", desc = "Reset Hunk" },
	{ "<leader>gs", "<cmd>lua require 'gitsigns'.stage_hunk()<cr>", desc = "Stage Hunk" },
	{ "<leader>gu", "<cmd>lua require 'gitsigns'.undo_stage_hunk()<cr>", desc = "Undo Stage Hunk" },
}

local lsp = {
	{ "<leader>l", group = "LSP" },
	{ "<leader>lR", "<cmd>:LspRestart<cr>", desc = "(R)estart LSPs" },
	{ "<leader>lS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", desc = "workspace (S)ymbols" },
	-- { "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>", desc = "Code (a)ction" },
	{ "<leader>la", "<cmd>lua require('tiny-code-action').code_action()<cr>", desc = "Code (a)ction" },
	{ "<leader>ld", "<cmd>Telescope lsp_document_diagnostics<cr>", desc = "(d)ocument diagnostics" },
	{ "<leader>lf", "<cmd>lua vim.lsp.buf.format{ async=true, name = 'efm' }<cr>", desc = "(f)ormat" },
	{ "<leader>li", desc = "organize (i)mports" },
	{ "<leader>lj", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", desc = "Next Diagnostic" },
	{ "<leader>lk", "<cmd>lua vim.lsp.diagnostic.goto_prev()<cr>", desc = "Prev Diagnostic" },
	{ "<leader>lh", "<cmd>lua require('user.lsp.handlers').toggle_inlay_hints()<cr>", desc = "inlay (h)ints" },
	{ "<leader>ll", "<cmd>lua vim.lsp.codelens.run()<cr>", desc = "Codea(l)ens Action" },
	{ "<leader>lq", "<cmd>lua vim.lsp.diagnostic.set_loclist()<cr>", desc = "(q)uickfix" },
	{ "<leader>lr", "<cmd>lua vim.lsp.buf.rename()<cr>", desc = "(r)ename" },
	{ "<leader>ls", "<cmd>Telescope lsp_document_symbols<cr>", desc = "document (s)ymbols" },
	{ "<leader>lw", "<cmd>Telescope lsp_workspace_diagnostics<cr>", desc = "(w)orkspace diagnostics" },
}

local mapping_n = utils.extend_lists(
	find_mapping.mapping_n,
	search_mapping.mapping_n,
	ai_mapping.mapping_n,
	replace_mapping.mapping_n,
	{
		{ "<leader>lc", "<Plug>ContextCommentaryLine", desc = "(c)omment" },
	}
)

local mapping_v = {
	mode = { "v" },
	utils.extend_lists(find_mapping.mapping_v, search_mapping.mapping_v, {
		{ "<leader>*", group = "CWord Under Cursor" },
		{
			"<leader>*f",
			"<cmd>lua require('user.telescope').find_files_from_root({default_text = vim.fn.expand('<cword>')})<CR>",
			desc = "(f)ile by name",
		},
		{
			"<leader>*h",
			"<cmd>lua require('user.telescope').live_grep_from_root({default_text = vim.fn.expand('<cword>')})<CR>",
			desc = "grep w(h)ole project",
		},

		{ "<leader>lc", "<Plug>ContextCommentary", desc = "(c)omment" },

		-- changes
		{ "<leader>c", group = "Changes" },
		{ "<leader>cc", "<esc><cmd>CompareClipboardSelection<cr>", desc = "compare (c)lipboard" },
		{
			"<leader>ch",
			"<Esc><Cmd>'<,'>DiffviewFileHistory --follow<CR>",
			desc = "(h)istory",
		},
	}, ai_mapping.mapping_v, replace_mapping.mapping_v),
}

-- Register mapping
which_key.setup({})

local shared_mapping = {
	root_mapping,
	-- surround,
	database,
	lazy_system,
	quit,
	repl,
	write_all,
	alpha,
	buffers,
	overseer,
	changes,
	debugging,
	git,
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
