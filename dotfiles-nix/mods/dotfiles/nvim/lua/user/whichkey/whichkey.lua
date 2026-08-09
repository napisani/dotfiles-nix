local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
	return
end
local utils = require("user.utils")
local replace_mapping = require("user.whichkey.replace")
local find_mapping = require("user.whichkey.find_snacks")
local search_mapping = require("user.whichkey.search_snacks")
local refresh = require("user.refresh")
local snacks_find_files = require("user.snacks.find_files")
local Snacks = require("snacks")
local repl = require("user.whichkey.repl")
local scopes = require("user.whichkey.scopes")
local lsp = require("user.whichkey.lsp")
local global_mappings = require("user.whichkey.global")
local plugin_keymaps = require("user.whichkey.plugins")
local discovered_plugin_keymaps = plugin_keymaps.get_all_plugin_keymaps()

local root_mapping = {
	{ '<leader>"', "<cmd>:split<cr>", desc = "Horizontal Split" },
	{ "<leader>%", "<cmd>:vsplit<cr>", desc = "Vertical Split" },
	{ "<leader>-", "<cmd>:Oil<cr>", desc = "(O)il" },
	{
		"<leader>t",
		function()
			snacks_find_files.toggle_explorer_tree()
		end,
		desc = "project (t)ree",
	},
	{ "<leader>q", "<cmd>q!<CR>", desc = "Quit" },
	-- { "<leader>K", "<cmd>:LegendaryRepeat<CR>", desc = "Repeat last (K)command" },
	-- { "<leader>lc", "<Plug>ContextCommentaryLine", desc = "(c)omment" },
}

local lazy_system = {
	{ "<leader>P", group = "Lazy/System" },
	{ "<leader>Pm", "<cmd>Mason<cr>", desc = "(m)ason" },
	{ "<leader>Ps", "<cmd>Lazy<cr>", desc = "(s)ync packages" },
	{ "<leader>Pt", "<cmd>TSUpdate<cr>", desc = "(t)reesitter update" },
	{ "<leader>Pl", "<cmd>LspInfo<cr>", desc = "(l)sp" },
	{ "<leader>PM", "<cmd>messages<cr>", desc = "(M)essages" },
	{ "<leader>PR", "<cmd>restart<cr>", desc = "(R)estart Neovim (0.12)" },
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
		refresh.all,
		desc = "R(e)fresh all buffers / trees / Diffview",
	},
}

local smart_refresh = {
	{
		"<leader>e",
		refresh.current,
		desc = "r(e)fresh buffer / tree / Diffview",
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

local mapping_n = utils.extend_lists(
	find_mapping.mapping_n,
	search_mapping.mapping_n,
	replace_mapping.mapping_n,
	repl.mapping_n,
	scopes.mapping_n,
	lsp.mapping_n,
	global_mappings.mapping_n,
	plugin_keymaps.get_normal_keymaps(discovered_plugin_keymaps)
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
		plugin_keymaps.get_visual_keymaps(discovered_plugin_keymaps)
	),
}

-- Register mapping
which_key.setup({})

local shared_mapping = {
	root_mapping,
	lazy_system,
	quit,
	write_all,
	reload_all,
	smart_refresh,
	buffers,
	-- overseer,
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
