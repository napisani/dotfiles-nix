local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
	return
end
local utils = require("user.utils")
local replace_mapping = require("user.whichkey.replace")
local find_mapping = require("user.whichkey.find_snacks")
local search_mapping = require("user.whichkey.search_snacks")
local Snacks = require("snacks")
local repl = require("user.whichkey.repl")
local scopes = require("user.whichkey.scopes")
local lsp = require("user.whichkey.lsp")
local global_mappings = require("user.whichkey.global")
local plugin_keymaps = require("user.whichkey.plugins")

local root_mapping = {
	{ '<leader>"', "<cmd>:split<cr>", desc = "Horizontal Split" },
	{ "<leader>%", "<cmd>:vsplit<cr>", desc = "Vertical Split" },
	{ "<leader>-", "<cmd>:Oil<cr>", desc = "(O)il" },
	{
		"<leader>t",
		function()
			require("user.snacks.find_files").toggle_explorer_tree()
		end,
		desc = "project (t)ree",
	},
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
	{ "<leader>Pl", "<cmd>LspInfo<cr>", desc = "(l)sp" },
	{ "<leader>PM", "<cmd>messages<cr>", desc = "(M)essages" },
	{
		"<leader>PN",
		desc = "(N)otifications",
		function()
			Snacks.notifier.show_history()
		end,
	},
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

local write_all = {
	{ "<leader>W", "<cmd>:wa<cr>", desc = "(w)rite all" },
}

local reload_all = {
	{
		"<leader>E",
		function()
			local reloaded = 0
			local failed = 0
			local skipped = 0

			-- Iterate through all buffers
			for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
				-- Only process loaded buffers
				if vim.api.nvim_buf_is_loaded(bufnr) then
					local bufname = vim.api.nvim_buf_get_name(bufnr)
					local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")

					-- Skip special buffers (help, terminal, quickfix, etc.)
					-- Only reload normal file buffers
					if buftype == "" and bufname ~= "" then
						-- Check if file exists
						if vim.fn.filereadable(bufname) == 1 then
							-- Save the current window and buffer
							local current_win = vim.api.nvim_get_current_win()
							local current_buf = vim.api.nvim_get_current_buf()

							-- Switch to the buffer's window if it's visible
							local win = vim.fn.bufwinid(bufnr)
							if win ~= -1 then
								vim.api.nvim_set_current_win(win)
							end

							-- Try to reload the buffer
							local success, err = pcall(function()
								vim.api.nvim_buf_call(bufnr, function()
									vim.cmd("edit!")
								end)
							end)

							if success then
								reloaded = reloaded + 1
							else
								failed = failed + 1
								vim.notify(
									"Failed to reload " .. vim.fn.fnamemodify(bufname, ":.") .. ": " .. tostring(err),
									vim.log.levels.WARN
								)
							end

							-- Restore the original window
							vim.api.nvim_set_current_win(current_win)
						else
							skipped = skipped + 1
						end
					else
						skipped = skipped + 1
					end
				end
			end

			-- Provide feedback
			local message = string.format("Reloaded %d buffer(s)", reloaded)
			if failed > 0 then
				message = message .. string.format(", %d failed", failed)
			end
			if skipped > 0 then
				message = message .. string.format(", %d skipped", skipped)
			end

			vim.notify(message, vim.log.levels.INFO)
		end,
		desc = "R(e)load all buffers",
	},
}

local smart_refresh = {
	{
		"<leader>e",
		function()
			vim.cmd("edit!")
			vim.notify("Buffer reloaded", vim.log.levels.INFO)
		end,
		desc = "r(e)fresh buffer/DiffView",
	},
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
	{
		"<leader>bpry",
		function()
			local buffer_path = vim.api.nvim_buf_get_name(0)
			if buffer_path == "" then
				return
			end
			local relative_path = vim.fn.fnamemodify(buffer_path, ":.")
			vim.fn.setreg("+", relative_path)
		end,
		desc = "(y)ank relative path",
	},

	{
		"<leader>bpgo",
		function()
			Snacks.gitbrowse()
		end,
		desc = "(o)pen in browser",
	},
}

-- local overseer = {
-- 	{ "<leader>o", group = "Overseer" },
-- 	{ "<leader>oo", "<cmd>:OverseerOpen<CR>", desc = "(O)pen" },
-- 	{ "<leader>oq", "<cmd>:OverseerClose<CR>", desc = "(q)uit" },
-- }

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

local mapping_n = utils.extend_lists(
	find_mapping.mapping_n,
	search_mapping.mapping_n,
	replace_mapping.mapping_n,
	repl.mapping_n,
	scopes.mapping_n,
	lsp.mapping_n,
	global_mappings.mapping_n,
	plugin_keymaps.get_normal_keymaps()
)

local mapping_v = {
	mode = { "v" },
	utils.extend_lists(
		find_mapping.mapping_v,
		search_mapping.mapping_v,
		{
			{ "<leader>lc", "<Plug>ContextCommentary", desc = "(c)omment" },
		},
		replace_mapping.mapping_v,
		repl.mapping_v,
		scopes.mapping_v,
		lsp.mapping_v,
		global_mappings.mapping_v,
		plugin_keymaps.get_visual_keymaps()
	),
}

-- Register mapping
which_key.setup({})

local shared_mapping = {
	root_mapping,
	database,
	lazy_system,
	quit,
	write_all,
	reload_all,
	smart_refresh,
	buffers,
	-- overseer,
	debugging,
	scopes.mapping_shared,
	lsp.mapping_shared,
	global_mappings.mapping_shared,
}

for _, mapping in ipairs(shared_mapping) do
	for _, m in ipairs(mapping) do
		table.insert(mapping_n, m)
		table.insert(mapping_v, m)
	end
end

which_key.add(mapping_n)
which_key.add(mapping_v)

return {
	mapping_n = mapping_n,
	mapping_v = mapping_v,
}

-- which_key.register(mapping_v, opts_v)
