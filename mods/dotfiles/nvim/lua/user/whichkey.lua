local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
	return
end
local utils = require("user.utils")
local primary_branch = utils.get_primary_git_branch()
local prod_branch = utils.get_prod_git_branch()
-- Shared mappings
local surround = {
	{ "<leader>s", group = "Surround" },
	{ "<leader>sa", desc = "Add surrounding in Normal and Visual modes" },
	{ "<leader>sd", desc = "Delete surrounding" },
	{ "<leader>sf", desc = "Find surrounding (to the right)" },
	{ "<leader>sF", desc = "Find surrounding (to the left)" },
	{ "<leader>sh", desc = "Highlight surrounding" },
	{ "<leader>sr", desc = "Replace surrounding" },
	{ "<leader>sn", desc = "Update `n_lines`" },
	{ "<leader>sl", desc = "Suffix to search with 'prev' method" },
	{ "<leader>sn", desc = "Suffix to search with 'next' method" },
}

local root_mappings = {
	{ '<leader>"', "<cmd>:split<cr>", desc = "Horizontal Split" },
	{ "<leader>%", "<cmd>:vsplit<cr>", desc = "Vertical Split" },
	{ "<leader>-", "<cmd>:Oil<cr>", desc = "(O)il" },
	{ "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "Explorer" },
	{ "<leader>o", "<cmd>:aboveleft Outline<cr>", desc = "(o)outline" },
}

-- -- Normal mode mappings
-- local cword_under_cursor = {
-- 	{ "<leader>*", group = "CWord Under Cursor" },
-- 	{
-- 		"<leader>*f",
-- 		"<cmd>lua require('user.telescope').find_files_from_root({default_text = vim.fn.expand('<cword>')})<CR>",
-- 		desc = "(f)ile by name",
-- 	},
-- 	{
-- 		"<leader>*h",
-- 		"<cmd>lua require('user.telescope').live_grep_from_root({default_text = vim.fn.expand('<cword>')})<CR>",
-- 		desc = "grep w(h)ole project",
-- 	},
-- 	{ "<leader>*r", group = "Replace" },
-- 	{ "<leader>*rB", ":%s@<C-R>=expand('<cword>')<CR>@@gc<left><left><left>", desc = "(B)uffer ask" },
-- 	{ "<leader>*rQ", ":cdo %s@<C-R>=expand('<cword>')<CR>@@gc<left><left><left>", desc = "(Q)uicklist ask" },
-- 	{ "<leader>*rb", ":%s@<C-R>=expand('<cword>')<CR>@@g<left><left>", desc = "(b)uffer" },
-- 	{ "<leader>*rl", ":s@<C-R>=expand('<cword>')<CR>@@g<left><left>", desc = "(l)ine" },
-- 	{ "<leader>*rq", ":cdo %s@<C-R>=expand('<cword>')<CR>@@g<left><left>", desc = "(q)uicklist" },
-- }

local database = {
	{ "<leader>D", group = "Database" },
	{ "<leader>Do", "<Cmd>DBUI<CR>", desc = "(o)pen" },
	{ "<leader>Dq", "<Cmd>DBUIClose<CR>", desc = "(q)uit" },
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
	{
		"<leader>hD",
		"<cmd>lua require('user.telescope').live_grep_git_changed_cmp_base_branch()<CR>",
		desc = "(D)iff git branch",
	},
	{ "<leader>hG", "<cmd>lua require('nvim-github-codesearch').prompt()<cr>", desc = "(G)ithub Code Search" },
	{ "<leader>hR", "<cmd>lua require('user.telescope').live_grep_in_directory()<CR>", desc = "grep (in directory)" },
	{ "<leader>hd", "<cmd>lua require('user.telescope').live_grep_git_changed_files()<CR>", desc = "(d)iff git files" },
	{ "<leader>hq", "<cmd>lua require('user.telescope').live_grep_qflist()<CR>", desc = "grep (q)uicklist" },
	{ "<leader>hr", "<cmd>lua require('user.telescope').live_grep_from_root()<CR>", desc = "grep from (r)oot" },
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

local mappings_n = {
	{ "<leader>f", group = "Find" },
	{ "<leader>fC", "<cmd>lua require('user.telescope').git_conflicts()<CR>", desc = "(C)onflicts" },
	{
		"<leader>fD",
		"<cmd>lua require('user.telescope').git_changed_cmp_base_branch()<CR>",
		desc = "(D)iff git branch",
	},
	{ "<leader>fM", "<cmd>Telescope man_pages<cr>", desc = "Man Pages" },

	{ "<leader>fQ", "<cmd>Telescope help_tags<cr>", desc = "Find Help" },
	{ "<leader>fR", "<cmd>Telescope registers<cr>", desc = "Registers" },
	{ "<leader>fS", "<cmd>lua require('user.neoscopes').neoscopes.select()<cr>", desc = "(S)copes" },
	{ "<leader>fc", desc = "(c)ommands" },
	{ "<leader>fcv", "<cmd>Telescope commands<cr>", desc = "neo(v)im commands" },
	{ "<leader>fcp", "<cmd>lua require('user.telescope').project_commands()<CR>", desc = "neo(v)im commands" },

	{ "<leader>fd", "<cmd>lua require('user.telescope').git_changed_files()<CR>", desc = "(d)iff git files" },
	{ "<leader>fe", "<cmd>lua require('user.telescope').search_buffers()<CR>", desc = "Buffers" },
	{ "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Keymaps" },
	{ "<leader>fo", "<cmd>Telescope colorscheme<cr>", desc = "C(o)lorscheme" },
	{ "<leader>fp", "<cmd>Telescope file_browser path=%:p:h<CR>", desc = "Project" },
	{ "<leader>fr", "<cmd>lua require('user.telescope').find_files_from_root()<CR>", desc = "(f)iles" },
	{ "<leader>fs", "<cmd>Telescope luasnip<cr>", desc = "(s)nippet" },
	{ "<leader>ft", "<cmd>lua require('user.telescope').search_git_files()<CR>", desc = "Git Files" },
	{
		"<leader>hD",
		"<cmd>lua require('user.telescope').live_grep_git_changed_cmp_base_branch()<CR>",
		desc = "(D)iff git branch",
	},
	{ "<leader>hG", "<cmd>lua require('nvim-github-codesearch').prompt()<cr>", desc = "(G)ithub Code Search" },
	{ "<leader>hR", "<cmd>lua require('user.telescope').live_grep_in_directory()<CR>", desc = "grep (in directory)" },
	{ "<leader>hd", "<cmd>lua require('user.telescope').live_grep_git_changed_files()<CR>", desc = "(d)iff git files" },
	{ "<leader>hq", "<cmd>lua require('user.telescope').live_grep_qflist()<CR>", desc = "grep (q)uicklist" },
	{ "<leader>hr", "<cmd>lua require('user.telescope').live_grep_from_root()<CR>", desc = "grep from (r)oot" },
	{ "<leader>l", group = "LSP" },
	{ "<leader>lR", "<cmd>:LspRestart<cr>", desc = "(R)estart LSPs" },
	{ "<leader>lS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", desc = "workspace (S)ymbols" },
	-- { "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>", desc = "Code (a)ction" },
	{ "<leader>la", "<cmd>lua require('tiny-code-action').code_action()<cr>", desc = "Code (a)ction" },
	{ "<leader>lc", "<Plug>ContextCommentaryLine", desc = "(c)omment" },
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

	{ "<leader>q", "<cmd>q!<CR>", desc = "Quit" },
	{ "<leader>r", group = "Replace" },
	{ "<leader>r*", ":%s@<C-R>=expand('<cword>')<CR>@@gc<left><left><left>", desc = "(*)word" },
	{ "<leader>rB", ":%s@@@gc<left><left><left><left>", desc = "(B)uffer ask" },
	{ "<leader>rD", ":g!@@d<left><left>", desc = "(D)elete else" },
	{ "<leader>rQ", ":cdo %s@@@gc<left><left><left><left>", desc = "(Q)uicklist ask" },
	{ "<leader>rb", ":%s@@@g<left><left><left>", desc = "(b)uffer" },
	{ "<leader>rd", ":g@@d<left><left>", desc = "(d)elete" },
	{ "<leader>rl", ":s@@@g<left><left><left>", desc = "(l)line" },
	{ "<leader>rq", ":cdo %s@@@g<left><left><left>", desc = "(q)uicklist" },
	{ "<leader>t", group = "ChatGPT" },
	{ "<leader>tA", "<cmd>:GpAskWithContext<cr>", desc = "(A)ppend results /w ctx" },
	{ "<leader>ta", "<cmd>:GpAppend<cr>", desc = "(a)ppend results" },
	{ "<leader>tc", "<cmd>:GpChatNew vsplit<cr>", desc = "(c)reate new chat" },
	{ "<leader>ti", "<cmd>:GpPrepend<cr>", desc = "(i)nsert/prepend results" },
	{ "<leader>tI", "<cmd>:GpRewrite<cr>", desc = "(I)nline / rewrite results" },
	{ "<leader>tn", "<cmd>:GpEnew<cr>", desc = "(n)ew buffer with results" },
	{ "<leader>to", "<cmd>:GpChatToggle<cr>", desc = "(o)pen existing chat" },
	{ "<leader>tp", "<cmd>:GpPopup<cr>", desc = "(p)opupresults" },
	{ "<leader>tq", "<cmd>:GpChatToggle<cr>", desc = "(q)uit chat" },
	{ "<leader>a", group = "AI" },
	{ "<leader>aA", ":ContextNvim add_current<cr>", desc = "(A)dd context" },
	{ "<leader>al", ":ContextNvim add_line_lsp_daig<cr>", desc = "(l)sp diag to context" },
	{ "<leader>aX", ":ContextNvim clear_manual<cr>", desc = "clear context" },

	{ "<leader>tr", group = "(r)run" },
	{ "<leader>trT", "<cmd>:GpUnitTestsWithContext<cr>", desc = "add (T)ests /w ctx" },
	{ "<leader>tre", "<cmd>:GpExplain<cr>", desc = "(e)xplian" },
	{ "<leader>tri", "<cmd>:GpImplement<cr>", desc = "(i)mplement" },
	{ "<leader>trn", "<cmd>:GpNameContext<cr>", desc = "(n)ame context" },
	{ "<leader>trt", "<cmd>:GpUnitTests<cr>", desc = "add (t)ests" },
	{ "<leader>ts", "<cmd>:GpStop<cr>", desc = "(s)stop streaming results" },

	{ "<leader>lc", "<Plug>ContextCommentaryLine", desc = "(c)omment" },

	{ "<leader>fa", desc = "(a)i" },
	{ "<leader>fam", "<cmd>:ContextNvim find_context_manual<cr>", desc = "(m)anual contexts" },
	{ "<leader>fah", "<cmd>:ContextNvim find_context_history<cr>", desc = "(h)istory_contexts" },
}

local mappings_v = {
	{
		mode = { "v" },
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
		{ "<leader>*r", group = "Replace" },
		{ "<leader>*rB", ":%s@<C-R>=expand('<cword>')<CR>@@gc<left><left><left>", desc = "(B)uffer ask" },
		{ "<leader>*rQ", ":cdo %s@<C-R>=expand('<cword>')<CR>@@gc<left><left><left>", desc = "(Q)uicklist ask" },
		{ "<leader>*rb", ":%s@<C-R>=expand('<cword>')<CR>@@g<left><left>", desc = "(b)uffer" },
		{ "<leader>*rl", ":s@<C-R>=expand('<cword>')<CR>@@g<left><left>", desc = "(l)ine" },
		{ "<leader>*rq", ":cdo %s@<C-R>=expand('<cword>')<CR>@@g<left><left>", desc = "(q)uicklist" },

		{ "<leader>R", group = "Replace" },
		{ "<leader>RB", '"4y:%s@<c-r>4@@gc<left><left><left>', desc = "(B)uffer ask" },
		{ "<leader>RQ", '"4y:cdo %s@c-r4@@gc<left><left><left>', desc = "(Q)uicklist ask" },
		{ "<leader>Rb", '"4y:%s@<c-r>4@@g<left><left>', desc = "(b)uffer" },
		{ "<leader>Rl", '"4y:s@<c-r>4@@g<left><left>', desc = "(l)line" },
		{ "<leader>Rq", '"4y:cdo %s@<c-r>4@@g<left><left>', desc = "(q)uicklist" },

		{ "<leader>f", group = "Find" },
		{
			"<leader>fC",
			'"4y<cmd>lua require("user.telescope").git_conflicts({default_text = vim.fn.getreg("4")})<CR>',
			desc = "(c)onflicts",
		},
		{
			"<leader>fD",
			'"4y<cmd>lua require("user.telescope").git_changed_cmp_base_branch({default_text = vim.fn.getreg("4")})<CR>',
			desc = "(D)iff git branch",
		},
		{ "<leader>fM", "<cmd>Telescope man_pages<cr>", desc = "Man Pages" },
		{ "<leader>fa", "<cmd>lua require('user.telescope').ai_contexts()<cr>", desc = "(a)i contexts" },
		{ "<leader>fQ", "<cmd>Telescope help_tags<cr>", desc = "Find Help" },
		{ "<leader>fR", "<cmd>Telescope registers<cr>", desc = "Registers" },
		{ "<leader>fS", "<cmd>lua require('user.neoscopes').neoscopes.select()<cr>", desc = "(S)copes" },
		{ "<leader>fc", desc = "(c)ommands" },
		{ "<leader>fcv", "<cmd>Telescope commands<cr>", desc = "neo(v)im commands" },
		{ "<leader>fcp", "<cmd>lua require('user.telescope').project_commands()<CR>", desc = "neo(v)im commands" },
		{
			"<leader>fd",
			'"4y<cmd>lua require("user.telescope").git_changed_files({default_text = vim.fn.getreg("4")})<CR>',
			desc = "(d)iff git files",
		},
		{
			"<leader>fe",
			'"4y<cmd>lua require("user.telescope").search_buffers({default_text = vim.fn.getreg("4")})<CR>',
			desc = "Buffers",
		},
		{ "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Keymaps" },
		{ "<leader>fo", "<cmd>Telescope colorscheme<cr>", desc = "C(o)lorscheme" },
		{ "<leader>fp", '"4y<cmd>Telescope file_browser path=%:p:h<CR><c-r>4', desc = "Project" },
		{
			"<leader>fr",
			'"4y<cmd>lua require("user.telescope").find_files_from_root({default_text = vim.fn.getreg("4")})<CR>',
			desc = "(f)iles",
		},
		{ "<leader>fs", "<cmd>Telescope luasnip<cr>", desc = "(s)nippet" },
		{
			"<leader>ft",
			'"4y<cmd>lua require("user.telescope").search_git_files({default_text = vim.fn.getreg("4")})<CR>',
			desc = "Git Files",
		},
		{
			"<leader>hD",
			'"4y<cmd>lua require("user.telescope").live_grep_git_changed_cmp_base_branch({default_text = vim.fn.getreg("4")})<CR>',
			desc = "(D)iff git branch",
		},
		{
			"<leader>hG",
			'"y<cmd>lua require("nvim-github-codesearch").prompt()<c-r>4<cr>',
			desc = "(G)ithub Code Search",
		},
		{
			"<leader>hR",
			'"4y<cmd>lua require("user.telescope").live_grep_in_directory({default_text = vim.fn.getreg("4")})<CR>',
			desc = "grep (in directory)",
		},
		{
			"<leader>hd",
			'"4y<cmd>lua require("user.telescope").live_grep_git_changed_files({default_text = vim.fn.getreg("4")})<CR>',
			desc = "(d)iff git files",
		},
		{
			"<leader>hq",
			'"4y<cmd>lua require("user.telescope").live_grep_qflist({default_text = vim.fn.getreg("4")})<CR>',
			desc = "grep (q)uicklist",
		},
		{
			"<leader>hr",
			'"4y<cmd>lua require("user.telescope").live_grep_from_root({default_text = vim.fn.getreg("4")})<CR>',
			desc = "grep from (r)oot",
		},

		{ "<leader>/", '"4y/<c-r>4', desc = "search in buffer" },

		-- { "<leader>p", group = "Paste to" },
		-- {
		-- 	"<leader>pf",
		-- 	"<cmd>lua require('user.telescope').find_files_from_root({default_text = vim.fn.getreg('*')})<CR>",
		-- 	desc = "find (f)ile by name",
		-- },
		-- {
		-- 	"<leader>ph",
		-- 	"<cmd>lua require('user.telescope').live_grep_from_root({default_text = vim.fn.getreg('*')})<CR>",
		-- 	desc = "grep w(h)ole project",
		-- },

		{ "<leader>r", group = "Replace" },
		{ "<leader>rB", '"4y:%s@<c-r>4@@gc<left><left><left>', desc = "(B)uffer ask" },
		{ "<leader>rD", '"4y:g!@<c-r>4@d<left><left>', desc = "(D)elete else" },
		{ "<leader>rQ", '"4y:cdo %s@<c-r>4@@gc<left><left><left>', desc = "(Q)uicklist ask" },
		{ "<leader>rV", ":s@@@gc<left><left><left>", desc = "(V)isual ask" },
		{ "<leader>rb", '"4y:%s@<c-r>4@@g<left><left>', desc = "(b)uffer" },
		{ "<leader>rd", '"4y:g@<c-r>4@d<left><left>', desc = "(d)elete" },
		{ "<leader>rl", '"4y:s@<c-r>4@@g<left><left>', desc = "(l)line" },
		{ "<leader>rq", '"4y:cdo %s@<c-r>4@@g<left><left>', desc = "(q)uicklist" },
		{ "<leader>rv", ":s@@@g<left><left><left>", desc = "(v)isual" },

		{ "<leader>t", group = "ChatGPT" },
		{ "<leader>tA", ":<C-u>'<,'>GpAskWithContext<cr>", desc = "(A)ppend results /w ctx" },
		{ "<leader>ta", ":<C-u>'<,'>GpAppend<cr>", desc = "(a)ppend results" },
		{ "<leader>tc", ":<C-u>'<,'>GpChatNew vsplit<cr>", desc = "(c)reate new chat" },
		{ "<leader>ti", ":<C-u>'<,'>GpPrepend<cr>", desc = "(i)nsert/prepend results" },
		{ "<leader>ti", ":<C-u>'<,'>GpRewrite<cr>", desc = "(I)nline / rewrite" },
		{ "<leader>tn", ":<C-u>'<,'>GpEnew<cr>", desc = "(n)ew buffer with results" },
		{ "<leader>to", ":<C-u>'<,'>GpChatToggle<cr>", desc = "(o)pen existing chat" },
		{ "<leader>tp", ":<C-u>'<,'>GpPopup<cr>", desc = "(p)opupresults" },
		{ "<leader>tq", ":<C-u>'<,'>GpChatToggle<cr>", desc = "(q)uit chat" },

		{ "<leader>a", group = "AI" },
		{ "<leader>aA", ":<C-u>'<,'>ContextNvim add_current<cr>", desc = "(A)dd context" },

		{ "<leader>tr", group = "(r)run" },
		{ "<leader>trT", "<cmd>:GpUnitTestsWithContext<cr>", desc = "add (T)ests /w ctx" },
		{ "<leader>tre", ":<C-u>'<,'>GpExplain<cr>", desc = "(e)xplian" },
		{ "<leader>tri", ":<C-u>'<,'>GpImplement<cr>", desc = "(i)mplement" },
		{ "<leader>trn", "<cmd>:GpNameContext<cr>", desc = "(n)ame context" },
		{ "<leader>trt", ":<C-u>'<,'>GpUnitTests<cr>", desc = "add (t)ests" },
		{ "<leader>ts", "<cmd>:GpStop<cr>", desc = "(s)stop streaming results" },

		{ "<leader>lc", "<Plug>ContextCommentary", desc = "(c)omment" },

		-- changes
		{ "<leader>c", group = "Changes" },
		{ "<leader>cc", "<esc><cmd>CompareClipboardSelection<cr>", desc = "compare (c)lipboard" },
		{
			"<leader>ch",
			"<Esc><Cmd>'<,'>DiffviewFileHistory --follow<CR>",
			desc = "(h)istory",
		},
	},
}

-- Register mappings
which_key.setup({})

local shared_mappings = {
	root_mappings,
	surround,
	database,
	lazy_system,
	quit,
	repl,
	write_all,
	alpha,
	buffers,
	changes,
	debugging,
	git,
	lsp,
}

for _, mappings in ipairs(shared_mappings) do
	for _, mapping in ipairs(mappings) do
		table.insert(mappings_n, mapping)
		table.insert(mappings_v, mapping)
	end
end

which_key.add(mappings_n)
which_key.add(mappings_v)

-- which_key.register(mappings_v, opts_v)
