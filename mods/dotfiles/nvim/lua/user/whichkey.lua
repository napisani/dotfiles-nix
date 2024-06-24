local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
	return
end
local utils = require("user.utils")
local primary_branch = utils.get_primary_git_branch()
local prod_branch = utils.get_prod_git_branch()

local setup = {
	plugins = {
		marks = true, -- shows a list of your marks on ' and `
		registers = true, -- shows your registers on " in NORMAL or <C-r> in INSERT mode
		spelling = {
			enabled = true, -- enabling this will show WhichKey when pressing z= to select spelling suggestions
			suggestions = 20, -- how many suggestions should be shown in the list?
		},
		-- the presets plugin, adds help for a bunch of default keybindings in Neovim
		-- No actual key bindings are created
		presets = {
			operators = false, -- adds help for operators like d, y, ... and registers them for motion / text object completion
			motions = true, -- adds help for motions
			text_objects = true, -- help for text objects triggered after entering an operator
			windows = true, -- default bindings on <c-w>
			nav = true, -- misc bindings to work with windows
			z = true, -- bindings for folds, spelling and others prefixed with z
			g = true, -- bindings for prefixed with g
		},
	},
	-- add operators that will trigger motion and text object completion
	-- to enable all native operators, set the preset / operators plugin above
	-- operators = { gc = "Comments" },
	key_labels = {
		-- override the label used to display some keys. It doesn't effect WK in any other way.
		-- For example:
		-- ["<space>"] = "SPC",
		-- ["<cr>"] = "RET",
		-- ["<tab>"] = "TAB",
	},
	icons = {
		breadcrumb = "»", -- symbol used in the command line area that shows your active key combo
		separator = "➜", -- symbol used between a key and it's label
		group = "+", -- symbol prepended to a group
	},
	popup_mappings = {
		scroll_down = "<c-d>", -- binding to scroll down inside the popup
		scroll_up = "<c-u>", -- binding to scroll up inside the popup
	},
	window = {
		border = "rounded", -- none, single, double, shadow
		position = "bottom", -- bottom, top
		margin = { 1, 0, 1, 0 }, -- extra window margin [top, right, bottom, left]
		padding = { 2, 2, 2, 2 }, -- extra window padding [top, right, bottom, left]
		winblend = 0,
	},
	layout = {
		height = { min = 4, max = 25 }, -- min and max height of the columns
		width = { min = 20, max = 50 }, -- min and max width of the columns
		spacing = 3, -- spacing between columns
		align = "left", -- align columns left, center or right
	},
	ignore_missing = true, -- enable this to hide mappings for which you didn't specify a label
	hidden = { "<silent>", "<cmd>", "<Cmd>", "<CR>", "call", "lua", "^:", "^ " }, -- hide mapping boilerplate
	show_help = true, -- show help message on the command line when the popup is visible
	triggers = "auto", -- automatically setup triggers
	-- triggers = {"<leader>"} -- or specify a list manually
	triggers_blacklist = {
		-- list of mode / prefixes that should never be hooked by WhichKey
		-- this is mostly relevant for key maps that start with a native binding
		-- most people should not need to change this
		i = { "j", "k" },
		v = { "j", "k" },
	},
}
vim.cmd([[ command! BuffOnly execute '%bdelete|edit #|normal `"' ]])
local opts = {
	mode = "n", -- NORMAL mode
	prefix = "<leader>",
	buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
	silent = true, -- use `silent` when creating keymaps
	noremap = true, -- use `noremap` when creating keymaps
	nowait = true, -- use `nowait` when creating keymaps
}

-- START of VISUAL mode mapping overrides -----------------
local opts_v = {
	mode = "v", -- VISUAL mode
	prefix = "<leader>",
	buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
	silent = true, -- use `silent` when creating keymaps
	noremap = true, -- use `noremap` when creating keymaps
	nowait = true, -- use `nowait` when creating keymaps
}

local mappings = {
	["%"] = { "<cmd>:vsplit<cr>", "Vertical Split" },
	['"'] = { "<cmd>:split<cr>", "Horizontal Split" },
	a = { "<cmd>Alpha<cr>", "Alpha" },
	e = { "<cmd>NvimTreeToggle<cr>", "Explorer" },
	w = { "<cmd>w!<CR>", "(w)rite" },
	q = { "<cmd>q!<CR>", "Quit" },
	x = { "<cmd>Bdelete!<CR>", "Close Buffer" },
	W = { "<cmd>:wa<cr>", "(w)rite all" },
	Q = { "<Cmd>:q<CR>", "(Q)uit" },

	-- buffer commands
	b = {
		name = "buffers",
		["q"] = { "<cmd>Bdelete!<CR>", "(q)uit Buffer" },
		["o"] = { "<cmd>BuffOnly<CR>", "(o)nly keep current Buffer" },
	},

	-- git commands
	g = {
		name = "Git",
		o = { "<Cmd>:Neogit<CR>", "Open neogit" },
		n = { "<cmd>lua require 'gitsigns'.next_hunk()<cr>", "Next Hunk" },
		p = { "<cmd>lua require 'gitsigns'.prev_hunk()<cr>", "Prev Hunk" },
		l = { "<cmd>lua require 'gitsigns'.blame_line()<cr>", "Blame" },
		P = { "<cmd>lua require 'gitsigns'.preview_hunk()<cr>", "Preview Hunk" },
		r = { "<cmd>lua require 'gitsigns'.reset_hunk()<cr>", "Reset Hunk" },
		R = { "<cmd>lua require 'gitsigns'.reset_buffer()<cr>", "Reset Buffer" },
		s = { "<cmd>lua require 'gitsigns'.stage_hunk()<cr>", "Stage Hunk" },
		u = {
			"<cmd>lua require 'gitsigns'.undo_stage_hunk()<cr>",
			"Undo Stage Hunk",
		},
		b = { "<cmd>Telescope git_branches<cr>", "Checkout branch" },
		C = { "<cmd>Telescope git_commits<cr>", "Checkout commit" },
		-- d = { "<cmd>Gitsigns diffthis HEAD<cr>", "Diff" },
		c = {
			name = "Checkout",
			m = { "<Cmd>:G checkout " .. primary_branch .. " -- %<CR>", "(m)ain" },
			M = { "<Cmd>:G checkout origin/" .. primary_branch .. "-- %<CR>", "origin/(M)ain" },

			p = { "<Cmd>:G checkout " .. prod_branch .. " -- %<CR>", "(p)rod" },
			P = { "<Cmd>:G checkout origin/" .. prod_branch .. " -- %<CR>", "origin/(P)rod" },

			h = { "<Cmd>:G checkout HEAD -- %<CR>", "HEAD" },
		},
	},

	-- change(git) commands
	c = {
		name = "Changes",
		o = { "<Cmd>:DiffviewOpen<CR>", "Open" },
		m = { "<Cmd>:DiffviewOpen " .. primary_branch .. "<CR>", "(m)ain" },
		M = { "<Cmd>:DiffviewOpen origin/" .. primary_branch .. "<CR>", "origin/(M)ain" },

		p = { "<Cmd>:DiffviewOpen " .. prod_branch .. "<CR>", "(p)rod" },
		P = { "<Cmd>:DiffviewOpen origin/" .. prod_branch .. "<CR>", "origin/(P)rod" },

		H = { "<Cmd>:DiffviewOpen HEAD<CR>", "diff (H)ead" },
		q = { "<Cmd>:DiffviewClose<CR>", "DiffviewClose" },

		f = {
			name = "(F)ile",
			m = { "<Cmd>:DiffviewOpen " .. primary_branch .. " -- %<CR>", "(m)ain" },
			M = { "<Cmd>:DiffviewOpen origin/" .. primary_branch .. "-- %<CR>", "origin/(M)ain" },

			p = { "<Cmd>:DiffviewOpen " .. prod_branch .. " -- %<CR>", "(p)rod" },
			P = { "<Cmd>:DiffviewOpen origin/" .. prod_branch .. " -- %<CR>", "origin/(P)rod" },

			h = { "<Cmd>:DiffviewFileHistory %<CR>", "File (H)istory" },
			H = { "<Cmd>:DiffviewOpen HEAD -- %<CR>", "diff (H)ead" },

			f = { "<cmd>lua require('user.telescope').find_file_from_root_to_compare_to()<CR>", "(f)ile" },
		},
		B = { "<Cmd>:G blame<CR>", "Blame" },
		y = "Choose YOURS",
		t = "Choose THEIRS",
		b = "Choose BASE",
		a = "Choose ALL",
		x = { '<Cmd>call feedkeys("dx")<CR>', "Choose DELETE" },
		T = { "<Cmd>:diffget<CR>", "get THEIRS (2-way diff)" },
	},

	-- debugger commands
	d = {
		name = "Debug",
		c = { "<Cmd>lua require'dap'.continue()<CR>", "continue/launch" },
		j = { "<Cmd>lua require'dap'.step_over()<CR>", "step over" },
		h = { "<Cmd>lua require'dap'.step_into()<CR>", "step_into" },
		k = { "<Cmd>lua require'dap'.step_out()<CR>", "step out" },
		b = { "<Cmd>lua require'dap'.toggle_breakpoint()<CR>", "toggle breakpoint" },
		B = {
			"<Cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>",
			"conditional breakpoint",
		},
		L = {
			"<Cmd>lua require'dap'.set_breakpoint(vim.fn.input(nil, nil, vim.fn.input('Log point message: ')))<CR>",
			"log point",
		},
		X = { "<Cmd>lua require'dap'.clear_breakpoints()<CR>", "Clear all Breakpoints" },
		r = { "<Cmd>lua require'dap'.repl.open()<CR>", "open REPL" },
		l = { "<Cmd>lua require'dap'.run_last()<CR>", "run last" },
		o = { "<Cmd>lua require'dapui'.open()<CR>", "open debugger" },
		q = { "<Cmd>lua require'dapui'.close()<CR>", "close debugger" },
	},

	-- database commands
	D = {
		name = "Database",
		o = { "<Cmd>DBUI<CR>", "(o)pen" },
		q = { "<Cmd>DBUIClose<CR>", "(q)uit" },
	},

	-- REPL commands
	R = {
		name = "REPL",
		o = {
			"<cmd>:IronRepl<cr>",
			"(O)pen REPL",
		},
		c = "send motion / visual send",
		f = "send (f)ile",
		l = "send (l)ine",
		m = {
			c = "mark motion/visual",
			d = "(d)elete mark",
		},
		-- '<cr>' = "send send carriage return",
		q = "(q)uit repl",
		x = "clear repl",
	},

	-- packer commands
	P = {
		name = "Packer/System",
		s = { "<cmd>PackerSync<cr>", "(s)ync" },
		t = { "<cmd>TSUpdate<cr>", "(t)reesitter update" },
    m = { "<cmd>Mason<cr>", "(m)ason" },
	},

	-- lsp commands
	l = {
		name = "LSP",
		a = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Code (a)ction" },
		c = { "<Plug>ContextCommentaryLine", "(c)omment" },
		d = {
			"<cmd>Telescope lsp_document_diagnostics<cr>",
			"(d)ocument diagnostics",
		},
		w = {
			"<cmd>Telescope lsp_workspace_diagnostics<cr>",
			"(w)orkspace diagnostics",
		},
		f = { "<cmd>lua vim.lsp.buf.format{ async=true, name = 'efm' }<cr>", "(f)ormat" },
		i = { "organize (i)mports" },
		-- i = { "<cmd>OrganizeImports<cr>", "organize (i)mports" },
		-- i = { "<cmd>LspInfo<cr>", "(i)nfo" },
		-- I = { "<cmd>LspInstallInfo<cr>", "(I)nstaller Info" },
		j = {
			"<cmd>lua vim.lsp.diagnostic.goto_next()<CR>",
			"Next Diagnostic",
		},
		k = {
			"<cmd>lua vim.lsp.diagnostic.goto_prev()<cr>",
			"Prev Diagnostic",
		},
		l = { "<cmd>lua vim.lsp.codelens.run()<cr>", "Codea(l)ens Action" },
		q = { "<cmd>lua vim.lsp.diagnostic.set_loclist()<cr>", "(q)uickfix" },
		r = { "<cmd>lua vim.lsp.buf.rename()<cr>", "(r)ename" },
		R = { "<cmd>:LspRestart<cr>", "(R)estart LSPs" },
		s = { "<cmd>Telescope lsp_document_symbols<cr>", "document (s)ymbols" },
		S = {
			"<cmd>Telescope lsp_dynamic_workspace_symbols<cr>",
			"workspace (S)ymbols",
		},
	},

	-- star commands
	["*"] = {
		name = "CWord Under Cursor",
		f = {
			"<cmd>lua require('user.telescope').find_files_from_root({default_text = vim.fn.expand('<cword>')})<CR>",
			"(f)ile by name",
		},
		h = {
			"<cmd>lua require('user.telescope').live_grep_from_root({default_text = vim.fn.expand('<cword>')})<CR>",
			"grep w(h)ole project",
		},
		r = {
			name = "Replace",

			l = { ":s@<C-R>=expand('<cword>')<CR>@@g<left><left>", "(l)ine" },
			b = { ":%s@<C-R>=expand('<cword>')<CR>@@g<left><left>", "(b)uffer" },
			B = { ":%s@<C-R>=expand('<cword>')<CR>@@gc<left><left><left>", "(B)uffer ask" },
			q = { ":cdo %s@<C-R>=expand('<cword>')<CR>@@g<left><left>", "(q)uicklist" },
			Q = { ":cdo %s@<C-R>=expand('<cword>')<CR>@@gc<left><left><left>", "(Q)uicklist ask" },
		},
	},

	-- replace commands
	r = {
		name = "Replace",
		l = { ":s@@@g<left><left><left>", "(l)line" },
		b = { ":%s@@@g<left><left><left>", "(b)uffer" },
		B = { ":%s@@@gc<left><left><left><left>", "(B)uffer ask" },
		["*"] = { ":%s@<C-R>=expand('<cword>')<CR>@@gc<left><left><left>", "(*)word" },
		q = { ":cdo %s@@@g<left><left><left>", "(q)uicklist" },
		Q = { ":cdo %s@@@gc<left><left><left><left>", "(Q)uicklist ask" },
    d = { ':g@@d<left><left>', "(d)elete" },
    D = { ':g!@@d<left><left>', "(D)elete else" },
	},

	-- paste commands
	p = {
		name = "Paste to",
		["b"] = {
			"/<c-r>0<cr>",
			"search in buffer",
		},

		f = {
			"<cmd>lua require('user.telescope').find_files_from_root({default_text = vim.fn.getreg('*')})<CR>",
			"find (f)ile by name",
		},
		h = {
			"<cmd>lua require('user.telescope').live_grep_from_root({default_text = vim.fn.getreg('*')})<CR>",
			"grep w(h)ole project",
		},
	},

	-- live grep commands
	h = {
		r = {
			"<cmd>lua require('user.telescope').live_grep_from_root()<CR>",
			"grep from (r)oot",
		},
		R = {
			"<cmd>lua require('user.telescope').live_grep_in_directory()<CR>",
			"grep (in directory)",
		},
		q = {
			"<cmd>lua require('user.telescope').live_grep_qflist()<CR>",
			"grep (q)uicklist",
		},
		d = {
			"<cmd>lua require('user.telescope').live_grep_git_changed_files()<CR>",
			"(d)iff git files",
		},
		D = {
			"<cmd>lua require('user.telescope').live_grep_git_changed_cmp_base_branch()<CR>",
			"(D)iff git branch",
		},
		G = { "<cmd>lua require('nvim-github-codesearch').prompt()<cr>", "(G)ithub Code Search" },
	},

	-- find commands
	f = {
		name = "Find",
		e = { "<cmd>lua require('user.telescope').search_buffers()<CR>", "Buffers" },
		r = { "<cmd>lua require('user.telescope').find_files_from_root()<CR>", "(f)iles" },
		t = { "<cmd>lua require('user.telescope').search_git_files()<CR>", "Git Files" },
		p = { "<cmd>Telescope file_browser path=%:p:h<CR>", "Project" },
		d = {
			"<cmd>lua require('user.telescope').git_changed_files()<CR>",
			"(d)iff git files",
		},
		D = {
			"<cmd>lua require('user.telescope').git_changed_cmp_base_branch()<CR>",
			"(D)iff git branch",
		},
		C = {
			"<cmd>lua require('user.telescope').git_conflicts()<CR>",
			"(C)onflicts",
		},
		c = { "<cmd>Telescope commands<cr>", "Commands" },
		o = { "<cmd>Telescope colorscheme<cr>", "C(o)lorscheme" },
		Q = { "<cmd>Telescope help_tags<cr>", "Find Help" },
		M = { "<cmd>Telescope man_pages<cr>", "Man Pages" },
		-- r = { "<cmd>Telescope oldfiles<cr>", "Open Recent File" },
		R = { "<cmd>Telescope registers<cr>", "Registers" },
		k = { "<cmd>Telescope keymaps<cr>", "Keymaps" },
		S = { "<cmd>lua require('user.neoscopes').neoscopes.select()<cr>", "(S)copes" },
		s = { "<cmd>Telescope luasnip<cr>", "(s)nippet" },
	},

	t = {
		name = "ChatGPT",
		c = { "<cmd>:GpChatNew<cr>", "(c)reate new chat" },
		o = { "<cmd>:GpChatToggle<cr>", "(o)pen existing chat" },
		q = { "<cmd>:GpChatToggle<cr>", "(q)uit chat" },
		a = { "<cmd>:GpAppend<cr>", "(a)ppend results" },
		A = { "<cmd>:GpAskWithContext<cr>", "(A)ppend results /w ctx" },
		i = { "<cmd>:GpPrepend<cr>", "(i)nsert/prepend results" },
		n = { "<cmd>:GpEnew<cr>", "(n)ew buffer with results" },
		p = { "<cmd>:GpPopup<cr>", "(p)opupresults" },
		s = { "<cmd>:GpStop<cr>", "(s)stop streaming results" },
		r = {
			name = "(r)run",
			n = { "<cmd>:GpNameContext<cr>", "(n)ame context" },
			t = { "<cmd>:GpUnitTests<cr>", "add (t)ests" },
			T = { "<cmd>:GpUnitTestsWithContext<cr>", "add (T)ests /w ctx" },
			e = { "<cmd>:GpExplain<cr>", "(e)xplian" },
			i = { "<cmd>:GpImplement<cr>", "(i)mplement" },
		},
	},

	-- oil commands
	["-"] = {
		"<cmd>:Oil<cr>",
		"(O)il",
	},
}

local mappings_spreader = utils.spread(mappings)
local mappings_v = mappings_spreader({

	-- lsp commands
	l = {
		name = "LSP",
		a = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Code (a)ction" },
		c = { "<Plug>ContextCommentary", "(c)omment" },
		d = {
			"<cmd>Telescope lsp_document_diagnostics<cr>",
			"(d)ocument diagnostics",
		},
		w = {
			"<cmd>Telescope lsp_workspace_diagnostics<cr>",
			"(w)orkspace diagnostics",
		},
		f = { "<cmd>lua vim.lsp.buf.format{ async=true, name = 'efm' }<cr>", "(f)ormat" },
		i = { "organize (i)mports" },
		-- i = { "<cmd>OrganizeImports<cr>", "organize (i)mports" },
		-- i = { "<cmd>LspInfo<cr>", "(i)nfo" },
		-- I = { "<cmd>LspInstallInfo<cr>", "(I)nstaller Info" },
		j = {
			"<cmd>lua vim.lsp.diagnostic.goto_next()<CR>",
			"Next Diagnostic",
		},
		k = {
			"<cmd>lua vim.lsp.diagnostic.goto_prev()<cr>",
			"Prev Diagnostic",
		},
		l = { "<cmd>lua vim.lsp.codelens.run()<cr>", "Codea(l)ens Action" },
		q = { "<cmd>lua vim.lsp.diagnostic.set_loclist()<cr>", "(q)uickfix" },
		r = { "<cmd>lua vim.lsp.buf.rename()<cr>", "(r)ename" },
		R = { "<cmd>:LspRestart<cr>", "(R)estart LSPs" },
		s = { "<cmd>Telescope lsp_document_symbols<cr>", "document (s)ymbols" },
		S = {
			"<cmd>Telescope lsp_dynamic_workspace_symbols<cr>",
			"workspace (S)ymbols",
		},
	},

	t = {
		name = "ChatGPT",
		c = { ":<C-u>'<,'>GpChatNew<cr>", "(c)reate new chat" },
		o = { ":<C-u>'<,'>GpChatToggle<cr>", "(o)pen existing chat" },
		q = { ":<C-u>'<,'>GpChatToggle<cr>", "(q)uit chat" },
		a = { ":<C-u>'<,'>GpAppend<cr>", "(a)ppend results" },
		i = { ":<C-u>'<,'>GpPrepend<cr>", "(i)nsert/prepend results" },
		n = { ":<C-u>'<,'>GpEnew<cr>", "(n)ew buffer with results" },
		A = { ":<C-u>'<,'>GpAskWithContext<cr>", "(A)ppend results /w ctx" },
		p = { ":<C-u>'<,'>GpPopup<cr>", "(p)opupresults" },
		s = { "<cmd>:GpStop<cr>", "(s)stop streaming results" },

		r = {
			name = "(r)run",
			n = { "<cmd>:GpNameContext<cr>", "(n)ame context" },
			t = { ":<C-u>'<,'>GpUnitTests<cr>", "add (t)ests" },
			T = { "<cmd>:GpUnitTestsWithContext<cr>", "add (T)ests /w ctx" },
			e = { ":<C-u>'<,'>GpExplain<cr>", "(e)xplian" },
			i = { ":<C-u>'<,'>GpImplement<cr>", "(i)mplement" },
		},
	},

	-- replace commands
	r = {
		name = "Replace",
		l = { '"4y:s@<c-r>4@@g<left><left>', "(l)line" },
		b = { '"4y:%s@<c-r>4@@g<left><left>', "(b)uffer" },
		B = { '"4y:%s@<c-r>4@@gc<left><left><left>', "(B)uffer ask" },
		q = { '"4y:cdo %s@<c-r>4@@g<left><left>', "(q)uicklist" },
		Q = { '"4y:cdo %s@c-r4@@gc<left><left><left>', "(Q)uicklist ask" },
    v = { ":s@@@g<left><left><left>", "(v)isual" },
    V = { ":s@@@gc<left><left><left>", "(V)isual ask" },
    d = { '"4y:g@<c-r>4@d<left><left>', "(d)elete" },
    D = { '"4y:g!@<c-r>4@d<left><left>', "(D)elete else" },
	},
	R = {
		name = "Replace",
		l = { '"4y:s@<c-r>4@<c-r>0@g<left><left>', "(l)line" },
		b = { '"4y:%s@<c-r>4@<c-r>0@g<left><left>', "(b)uffer" },
		B = { '"4y:%s@<c-r>4@<c-r>0@gc<left><left><left>', "(B)uffer ask" },
		q = { '"4y:cdo %s@<c-r>4@<c-r>0@g<left><left>', "(q)uicklist" },
		Q = { '"4y:cdo %s@c-r4@<c-r>0@gc<left><left><left>', "(Q)uicklist ask" },
	},

	-- live grep commands
	h = {
		r = {
			'"4y<cmd>lua require("user.telescope").live_grep_from_root({default_text = vim.fn.getreg("4")})<CR>',
			"grep from (r)oot",
		},
		R = {
			'"4y<cmd>lua require("user.telescope").live_grep_in_directory({default_text = vim.fn.getreg("4")})<CR>',
			"grep (in directory)",
		},
		q = {
			'"4y<cmd>lua require("user.telescope").live_grep_qflist({default_text = vim.fn.getreg("4")})<CR>',
			"grep (q)uicklist",
		},
		d = {
			'"4y<cmd>lua require("user.telescope").live_grep_git_changed_files({default_text = vim.fn.getreg("4")})<CR>',
			"(d)iff git files",
		},
		D = {
			'"4y<cmd>lua require("user.telescope").live_grep_git_changed_cmp_base_branch({default_text = vim.fn.getreg("4")})<CR>',
			"(D)iff git branch",
		},
		-- todo this does not paste the word under cursor
		G = { '"y<cmd>lua require("nvim-github-codesearch").prompt()<c-r>4<cr>', "(G)ithub Code Search" },
	},

	-- find commands
	f = {
		name = "Find",
		e = {
			'"4y<cmd>lua require("user.telescope").search_buffers({default_text = vim.fn.getreg("4")})<CR>',
			"Buffers",
		},
		r = {
			'"4y<cmd>lua require("user.telescope").find_files_from_root({default_text = vim.fn.getreg("4")})<CR>',
			"(f)iles",
		},
		t = {
			'"4y<cmd>lua require("user.telescope").search_git_files({default_text = vim.fn.getreg("4")})<CR>',
			"Git Files",
		},
		p = { '"4y<cmd>Telescope file_browser path=%:p:h<CR><c-r>4', "Project" },
		d = {
			'"4y<cmd>lua require("user.telescope").git_changed_files({default_text = vim.fn.getreg("4")})<CR>',
			"(d)iff git files",
		},
		D = {
			'"4y<cmd>lua require("user.telescope").git_changed_cmp_base_branch({default_text = vim.fn.getreg("4")})<CR>',
			"(D)iff git branch",
		},
		C = {
			'"4y<cmd>lua require("user.telescope").git_conflicts({default_text = vim.fn.getreg("4")})<CR>',
			"(c)onflicts",
		},

		-- todo this does not paste the word under cursor
		c = { "<cmd>Telescope commands<cr>", "Commands" },
		o = { "<cmd>Telescope colorscheme<cr>", "C(o)lorscheme" },
		Q = { "<cmd>Telescope help_tags<cr>", "Find Help" },
		M = { "<cmd>Telescope man_pages<cr>", "Man Pages" },
		R = { "<cmd>Telescope registers<cr>", "Registers" },
		k = { "<cmd>Telescope keymaps<cr>", "Keymaps" },
		S = { "<cmd>lua require('user.neoscopes').neoscopes.select()<cr>", "(S)copes" },
		s = { "<cmd>Telescope luasnip<cr>", "(s)nippet" },
	},
})

which_key.setup(setup)
-- register mappings for both normal and visual mode
which_key.register(mappings, opts)
which_key.register(mappings_v, opts_v)
