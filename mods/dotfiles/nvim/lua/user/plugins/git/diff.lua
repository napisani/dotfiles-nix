local M = {}

local api = vim.api

---Prefer the focused diff window; fall back to Diffview's "main" window.
---@return unknown? win
---@return integer? bufnr
local function get_diffview_nav_win(view)
	if not view or not view.cur_layout then
		return nil, nil
	end
	local cur = api.nvim_get_current_win()
	for _, w in ipairs(view.cur_layout.windows or {}) do
		if w.id == cur and w:is_valid() and w.file and w.file:is_valid() then
			return w, w.file.bufnr
		end
	end
	local main = view.cur_layout:get_main_win()
	if main and main:is_valid() and main.file and main.file:is_valid() then
		return main, main.file.bufnr
	end
	return nil, nil
end

---Land on the last diff hunk in the current file (after switching to the previous file).
local function jump_to_last_change(view)
	local utils = require("diffview.utils")
	local nav_win, bufnr = get_diffview_nav_win(view)
	if not nav_win then
		return
	end

	api.nvim_win_call(nav_win.id, function()
		if view.cur_entry and view.cur_entry.kind == "conflicting" then
			utils.set_cursor(0, api.nvim_buf_line_count(0), 0)
			pcall(vim.cmd, "norm! [c")
		elseif view.cur_layout.name == "diff1_inline" then
			local rows = require("diffview.scene.inline_diff").hunk_anchor_rows(bufnr)
			local last = rows[#rows]
			if last then
				api.nvim_win_set_cursor(0, { last + 1, 0 })
			end
		else
			utils.set_cursor(0, api.nvim_buf_line_count(bufnr), 0)
			pcall(vim.cmd, "norm! [c")
		end
		vim.cmd("norm! zz")
	end)
	view.cur_layout:sync_scroll()
end

local function diffview_next_hunk_or_next_file()
	local lib = require("diffview.lib")
	local actions = require("diffview.actions")
	local view = lib.get_current_view()
	if not view then
		return
	end

	local nav_win, bufnr = get_diffview_nav_win(view)
	if not nav_win then
		return
	end

	local moved = false
	api.nvim_win_call(nav_win.id, function()
		if view.cur_layout.name == "diff1_inline" then
			local cur = api.nvim_win_get_cursor(0)[1] - 1
			local row = require("diffview.scene.inline_diff").next_hunk_row(bufnr, cur)
			if row then
				api.nvim_win_set_cursor(0, { row + 1, 0 })
				moved = true
			end
		else
			local row_before = api.nvim_win_get_cursor(0)[1]
			pcall(vim.cmd, "norm! ]c")
			moved = api.nvim_win_get_cursor(0)[1] ~= row_before
		end
		if moved then
			vim.cmd("norm! zz")
		end
	end)

	if moved then
		view.cur_layout:sync_scroll()
		return
	end

	local before_entry = view.cur_entry
	require("diffview").emit("select_next_entry")
	-- Diffview loads the next file asynchronously; defer twice so `cur_entry` has updated.
	vim.schedule(function()
		vim.schedule(function()
			local v2 = lib.get_current_view()
			if not v2 or v2.cur_entry == before_entry then
				return
			end
			actions.jump_to_first_change(v2)
		end)
	end)
end

local function diffview_prev_hunk_or_prev_file()
	local lib = require("diffview.lib")
	local view = lib.get_current_view()
	if not view then
		return
	end

	local nav_win, bufnr = get_diffview_nav_win(view)
	if not nav_win then
		return
	end

	local moved = false
	api.nvim_win_call(nav_win.id, function()
		if view.cur_layout.name == "diff1_inline" then
			local cur = api.nvim_win_get_cursor(0)[1] - 1
			local row = require("diffview.scene.inline_diff").prev_hunk_row(bufnr, cur)
			if row then
				api.nvim_win_set_cursor(0, { row + 1, 0 })
				moved = true
			end
		else
			local row_before = api.nvim_win_get_cursor(0)[1]
			pcall(vim.cmd, "norm! [c")
			moved = api.nvim_win_get_cursor(0)[1] ~= row_before
		end
		if moved then
			vim.cmd("norm! zz")
		end
	end)

	if moved then
		view.cur_layout:sync_scroll()
		return
	end

	local before_entry = view.cur_entry
	require("diffview").emit("select_prev_entry")
	vim.schedule(function()
		vim.schedule(function()
			local v2 = lib.get_current_view()
			if not v2 or v2.cur_entry == before_entry then
				return
			end
			jump_to_last_change(v2)
		end)
	end)
end

---Exported for `gitsigns` which-key mappings: global `]g` / `[g` win over Diffview buffer maps.
function M.hunk_next()
	diffview_next_hunk_or_next_file()
end

function M.hunk_prev()
	diffview_prev_hunk_or_prev_file()
end

local function open_local_changes_tree()
	require("user.snacks.git_files").git_changed_files_tree()
end

local function open_branch_changes_tree()
	require("user.snacks.git_files").git_changed_cmp_base_branch_tree()
end

local function split_diffopt(diffopt_str)
	local parts = vim.split(diffopt_str, ",", { plain = true, trimempty = true })
	return parts
end

function M.setup()
	vim.api.nvim_create_user_command("NewScratchBuf", function()
		vim.cmd([[
      execute 'vsplit | enew'
      setlocal buftype=nofile
      setlocal bufhidden=hide
      setlocal noswapfile
    ]])
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("CompareClipboard", function()
		local ftype = vim.api.nvim_eval("&filetype")
		vim.cmd([[
      tabnew %
      NewScratchBuf
      normal! P
      windo diffthis
    ]])
		vim.cmd("set filetype=" .. ftype)
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("CompareClipboardSelection", function()
		vim.cmd([[
      normal! gv"zy
      execute 'tabnew | setlocal buftype=nofile bufhidden=hide noswapfile'
      normal! V"zp
      NewScratchBuf
      normal! Vp
      windo diffthis
    ]])
	end, {
		nargs = 0,
		range = true,
	})

	vim.o.diffopt = "internal,filler,closeoff,indent-heuristic,linematch:60,algorithm:histogram"

	---@return boolean
	local function is_in_diffview()
		local ok, lib = pcall(require, "diffview.lib")
		if not ok or not lib.get_current_view then
			return false
		end
		return lib.get_current_view() ~= nil
	end

	local function refresh_diffview()
		if not is_in_diffview() then
			vim.notify("No diff view open", vim.log.levels.INFO)
			return
		end

		pcall(vim.cmd, "DiffviewRefresh")

		local current_tab = vim.api.nvim_get_current_tabpage()
		local wins = vim.api.nvim_tabpage_list_wins(current_tab)
		local refreshed = false

		for _, win in ipairs(wins) do
			local buf = vim.api.nvim_win_get_buf(win)
			local buf_name = vim.api.nvim_buf_get_name(buf)
			local buftype = vim.bo[buf].buftype

			if buftype == "" and buf_name ~= "" then
				local modified = vim.bo[buf].modified
				if not modified then
					vim.api.nvim_buf_call(buf, function()
						vim.cmd("checktime")
					end)
					refreshed = true
				end
			end
		end

		if refreshed then
			vim.notify("Diffview refreshed", vim.log.levels.INFO)
		else
			vim.notify("Diffview refresh: no file buffers to reload", vim.log.levels.INFO)
		end
	end

	vim.api.nvim_create_user_command("DiffviewReloadBuffers", refresh_diffview, {
		desc = "Refresh Diffview file list and reload on-disk file buffers in the tab",
	})

	_G.diffview_refresh = refresh_diffview

	local status_ok, diffview = pcall(require, "diffview")
	if not status_ok then
		return
	end

	local actions = require("diffview.actions")

	diffview.setup({
		enhanced_diff_hl = true,
		use_icons = true,
		watch_index = true,
		hide_merge_artifacts = false,
		diffopt = split_diffopt(vim.o.diffopt),
		file_panel = {
			listing_style = "tree",
			win_config = { position = "left", width = 70 },
			tree_options = {
				flatten_dirs = true,
				folder_statuses = "only_folded",
				folder_count_style = "grouped",
				folder_trailing_slash = true,
			},
		},
		file_history_panel = {
			win_config = { position = "bottom", height = 15 },
			stat_style = "number",
			subject_highlight = "ref_aware",
			commit_format = { "status", "files", "stats", "hash", "reflog", "ref", "subject", "author", "date" },
		},
		keymaps = {
			disable_defaults = false,
			view = {
				["<leader>e"] = false,
				["<leader>b"] = false,
				{ "n", "<leader>ge", actions.focus_files, { desc = "Bring focus to the file panel" } },
				{ "n", "<leader>t", actions.toggle_files, { desc = "Toggle the file panel" } },
				{ "n", "q", actions.close, { desc = "Close diffview" } },
				{
					"n",
					"]g",
					diffview_next_hunk_or_next_file,
					{ desc = "Next hunk (next file at EOF)" },
				},
				{
					"n",
					"[g",
					diffview_prev_hunk_or_prev_file,
					{ desc = "Previous hunk (previous file at BOF)" },
				},
				{ "n", "]f", actions.select_next_entry, { desc = "Open the diff for the next file" } },
				{ "n", "[f", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
			},
			file_panel = {
				["<leader>e"] = false,
				["<leader>b"] = false,
				{ "n", "<leader>ge", actions.focus_files, { desc = "Bring focus to the file panel" } },
				{ "n", "<leader>t", actions.toggle_files, { desc = "Toggle the file panel" } },
				{ "n", "q", actions.close, { desc = "Close diffview" } },
				{ "n", "]f", actions.select_next_entry, { desc = "Open the diff for the next file" } },
				{ "n", "[f", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
			},
			file_history_panel = {
				["<leader>e"] = false,
				["<leader>b"] = false,
				{ "n", "<leader>ge", actions.focus_files, { desc = "Bring focus to the file panel" } },
				{ "n", "<leader>t", actions.toggle_files, { desc = "Toggle the file panel" } },
				{ "n", "q", actions.close, { desc = "Close diffview" } },
				{ "n", "]f", actions.select_next_entry, { desc = "Open the diff for the next file" } },
				{ "n", "[f", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
			},
		},
	})
end

function M.get_keymaps()
	local utils = require("user.utils")

	return {
		normal = {
			{ "<leader>c", group = "Changes" },

			{
				"<leader>cr",
				function()
					local ref = utils.get_git_ref()
					vim.cmd("DiffviewOpen " .. ref)
				end,
				desc = "compare to ref",
			},

			{ "<leader>cB", "<Cmd>:G blame<CR>", desc = "Blame" },
			{ "<leader>cH", "<Cmd>:DiffviewOpen HEAD<CR>", desc = "diff (H)ead" },
			{ "<leader>ch", "<Cmd>:DiffviewFileHistory<CR>", desc = "(h)istory" },
			{ "<leader>co", "<Cmd>:DiffviewOpen<CR>", desc = "Open" },
			{ "<leader>ct", open_local_changes_tree, desc = "local changes tree" },
			{ "<leader>cT", open_branch_changes_tree, desc = "branch changes tree" },
			{
				"<leader>cq",
				function()
					local ok, lib = pcall(require, "diffview.lib")
					if ok and lib.get_current_view and lib.get_current_view() then
						vim.cmd("DiffviewClose")
					else
						vim.notify("No diff view open", vim.log.levels.INFO)
					end
				end,
				desc = "Close diff view",
			},

			{ "<leader>cf", group = "(F)ile" },
			{ "<leader>cfH", "<Cmd>:DiffviewOpen HEAD -- %<CR>", desc = "diff (H)ead" },
			{
				"<leader>cfr",
				function()
					local ref = utils.get_git_ref()
					vim.cmd("DiffviewOpen " .. ref .. " -- %")
				end,
				desc = "compare to ref",
			},
			{
				"<leader>cff",
				"<cmd>lua require('user.snacks.compare').find_file_from_root_to_compare_to()<CR>",
				desc = "(f)ile",
			},
			{ "<leader>cfh", "<Cmd>:DiffviewFileHistory --max-count=20 %<CR>", desc = "(h)istory" },
			{ "<leader>cfc", "<cmd>CompareClipboard<cr>", desc = "compare (c)lipboard" },
		},

		visual = {
			{ "<leader>c", group = "Changes" },
			{ "<leader>cc", "<esc><cmd>CompareClipboardSelection<cr>", desc = "compare (c)lipboard" },
			{
				"<leader>ch",
				function()
					vim.cmd("DiffviewFileHistory --max-count=20 %")
				end,
				desc = "(h)istory",
			},
		},

		shared = {},
	}
end

return M
