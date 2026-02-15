local M = {}

function M.setup()
	-- Create a new scratch buffer
	vim.api.nvim_create_user_command("NewScratchBuf", function()
		vim.cmd([[
      execute 'vsplit | enew'
      setlocal buftype=nofile
      setlocal bufhidden=hide
      setlocal noswapfile
    ]])
	end, { nargs = 0 })

	-- Compare clipboard to current buffer
	vim.api.nvim_create_user_command("CompareClipboard", function()
		local ftype = vim.api.nvim_eval("&filetype") -- original filetype
		vim.cmd([[
      tabnew %
      NewScratchBuf
      normal! P
      windo diffthis
    ]])
		vim.cmd("set filetype=" .. ftype)
	end, { nargs = 0 })

	-- Compare clipboard to visual selection
	vim.api.nvim_create_user_command("CompareClipboardSelection", function()
		vim.cmd([[
      " yank visual selection to z register
      normal! gv"zy
      " open new tab, set options to prevent save prompt when closing
      execute 'tabnew | setlocal buftype=nofile bufhidden=hide noswapfile'
      " paste z register into new buffer
      normal! V"zp
      NewScratchBuf
      normal! Vp
      windo diffthis
    ]])
	end, {
		nargs = 0,
		range = true,
	})

	-- improve the diff presentation
	vim.o.diffopt = "internal,filler,closeoff,indent-heuristic,linematch:60,algorithm:histogram"

	-- Helper function to check if we're in a CodeDiff view
	local function is_in_codediff_view()
		local current_tab = vim.api.nvim_get_current_tabpage()
		local wins = vim.api.nvim_tabpage_list_wins(current_tab)

		for _, win in ipairs(wins) do
			local buf = vim.api.nvim_win_get_buf(win)
			local buf_name = vim.api.nvim_buf_get_name(buf)
			local filetype = vim.bo[buf].filetype

			-- Check for CodeDiff indicators
			if buf_name:match("codediff") or filetype == "codediff" then
				return true
			end

			-- Check for CodeDiff window variable
			local ok, is_codediff = pcall(vim.api.nvim_win_get_var, win, "codediff")
			if ok and is_codediff then
				return true
			end
		end

		return false
	end

	-- Refresh function for CodeDiff views
	local function refresh_codediff()
		if not is_in_codediff_view() then
			vim.notify("No CodeDiff view open", vim.log.levels.INFO)
			return
		end

		-- Get all windows in current tab
		local current_tab = vim.api.nvim_get_current_tabpage()
		local wins = vim.api.nvim_tabpage_list_wins(current_tab)
		local refreshed = false

		for _, win in ipairs(wins) do
			local buf = vim.api.nvim_win_get_buf(win)
			local buf_name = vim.api.nvim_buf_get_name(buf)
			local buftype = vim.bo[buf].buftype

			-- Only reload buffers that are backed by actual files (not scratch/nofile buffers)
			if buftype == "" and buf_name ~= "" then
				-- Check if file is modified externally
				local modified = vim.bo[buf].modified
				if not modified then
					-- Reload the buffer from disk
					vim.api.nvim_buf_call(buf, function()
						vim.cmd("checktime")
					end)
					refreshed = true
				end
			end
		end

		if refreshed then
			vim.notify("CodeDiff refreshed", vim.log.levels.INFO)
		else
			vim.notify("CodeDiff refresh: no file buffers to reload", vim.log.levels.INFO)
		end
	end

	-- Create user commands for refreshing
	vim.api.nvim_create_user_command("CodeDiffRefresh", refresh_codediff, {
		desc = "Refresh CodeDiff view by reloading buffers from disk",
	})

	-- Store the refresh function globally so keymaps can access it
	_G.code_diff_refresh = refresh_codediff

	-- Configure CodeDiff.nvim
	local status_ok, codediff = pcall(require, "codediff")
	if status_ok then
		codediff.setup({
			-- Highlight configuration
			highlights = {
				-- Line-level: accepts highlight group names or hex colors
				line_insert = "DiffAdd", -- Line-level insertions
				line_delete = "DiffDelete", -- Line-level deletions

				-- Character-level: accepts highlight group names or hex colors
				-- If specified, these override char_brightness calculation
				char_insert = nil, -- Character-level insertions (nil = auto-derive)
				char_delete = nil, -- Character-level deletions (nil = auto-derive)

				-- Brightness multiplier (only used when char_insert/char_delete are nil)
				-- nil = auto-detect based on background (1.4 for dark, 0.92 for light)
				char_brightness = nil, -- Auto-adjust based on your colorscheme

				-- Conflict sign highlights (for merge conflict views)
				conflict_sign = nil, -- Unresolved: DiagnosticSignWarn -> #f0883e
				conflict_sign_resolved = nil, -- Resolved: Comment -> #6e7681
				conflict_sign_accepted = nil, -- Accepted: GitSignsAdd -> DiagnosticSignOk -> #3fb950
				conflict_sign_rejected = nil, -- Rejected: GitSignsDelete -> DiagnosticSignError -> #f85149
			},

			-- Diff view behavior
			diff = {
				disable_inlay_hints = true, -- Disable inlay hints in diff windows for cleaner view
				max_computation_time_ms = 5000, -- Maximum time for diff computation (VSCode default)
				hide_merge_artifacts = false, -- Hide merge tool temp files (*.orig, *.BACKUP.*, *.BASE.*, *.LOCAL.*, *.REMOTE.*)
				original_position = "left", -- Position of original (old) content: "left" or "right"
				conflict_ours_position = "right", -- Position of ours (:2) in conflict view: "left" or "right"
			},

			-- Explorer panel configuration
			explorer = {
				position = "left", -- "left" or "bottom"
				width = 40, -- Width when position is "left" (columns)
				height = 15, -- Height when position is "bottom" (lines)
				indent_markers = true, -- Show indent markers in tree view (│, ├, └)
				initial_focus = "explorer", -- Initial focus: "explorer", "original", or "modified"
				icons = {
					folder_closed = "", -- Nerd Font folder icon (customize as needed)
					folder_open = "", -- Nerd Font folder-open icon
				},
				view_mode = "tree", -- "list" or "tree"
				file_filter = {
					ignore = {}, -- Glob patterns to hide (e.g., {"*.lock", "dist/*"})
				},
			},

			-- History panel configuration (for :CodeDiff history)
			history = {
				position = "bottom", -- "left" or "bottom" (default: bottom)
				width = 40, -- Width when position is "left" (columns)
				height = 15, -- Height when position is "bottom" (lines)
				initial_focus = "history", -- Initial focus: "history", "original", or "modified"
				view_mode = "list", -- "list" or "tree" for files under commits
			},

			-- Keymaps in diff view
			keymaps = {
				view = {
					quit = "q", -- Close diff tab
					toggle_explorer = "<leader>t", -- Toggle explorer visibility (explorer mode only)
					next_hunk = "]g", -- Jump to next change
					prev_hunk = "[g", -- Jump to previous change
					next_file = "]f", -- Next file in explorer/history mode
					prev_file = "[f", -- Previous file in explorer/history mode
					diff_get = "do", -- Get change from other buffer (like vimdiff)
					diff_put = "dp", -- Put change to other buffer (like vimdiff)
					open_in_prev_tab = "gf", -- Open current buffer in previous tab (or create one before)
					toggle_stage = "-", -- Stage/unstage current file (works in explorer and diff buffers)
				},
				explorer = {
					select = "<CR>", -- Open diff for selected file
					hover = "K", -- Show file diff preview
					refresh = "R", -- Refresh git status
					toggle_view_mode = "i", -- Toggle between 'list' and 'tree' views
					stage_all = "S", -- Stage all files
					unstage_all = "U", -- Unstage all files
					restore = "X", -- Discard changes (restore file)
				},
				history = {
					select = "<CR>", -- Select commit/file or toggle expand
					toggle_view_mode = "i", -- Toggle between 'list' and 'tree' views
				},
				conflict = {
					accept_incoming = "<leader>ct", -- Accept incoming (theirs/left) change
					accept_current = "<leader>co", -- Accept current (ours/right) change
					accept_both = "<leader>cb", -- Accept both changes (incoming first)
					discard = "<leader>cx", -- Discard both, keep base
					next_conflict = "]x", -- Jump to next conflict
					prev_conflict = "[x", -- Jump to previous conflict
					diffget_incoming = "2do", -- Get hunk from incoming (left/theirs) buffer
					diffget_current = "3do", -- Get hunk from current (right/ours) buffer
				},
			},
		})
	end
end

function M.get_keymaps()
	local utils = require("user.utils")

	return {
		normal = {
			-- NOTE: <leader>e and <leader>E are defined in whichkey.lua
			-- They will call _G.code_diff_refresh() when in a CodeDiff view

			{ "<leader>c", group = "Changes" },

			{
				"<leader>cr",
				function()
					local ref = utils.get_git_ref()
					vim.cmd("CodeDiff " .. ref)
				end,
				desc = "compare to ref",
			},

			{ "<leader>cB", "<Cmd>:G blame<CR>", desc = "Blame" },
			{ "<leader>cH", "<Cmd>:CodeDiff HEAD<CR>", desc = "diff (H)ead" },
			{ "<leader>ch", "<Cmd>:CodeDiff history<CR>", desc = "(h)istory" },
			{ "<leader>co", "<Cmd>:CodeDiff<CR>", desc = "Open" },
			{
				"<leader>cq",
				function()
					-- Check if we're in a CodeDiff view by looking for CodeDiff buffer variables
					local in_codediff = false
					local current_tab = vim.api.nvim_get_current_tabpage()
					local wins = vim.api.nvim_tabpage_list_wins(current_tab)

					for _, win in ipairs(wins) do
						local buf = vim.api.nvim_win_get_buf(win)
						local buf_name = vim.api.nvim_buf_get_name(buf)
						-- CodeDiff buffers typically have "codediff" in the name or are diff views
						if buf_name:match("codediff") or vim.bo[buf].filetype == "codediff" then
							in_codediff = true
							break
						end
					end

					-- Also check if any window has the codediff variable set
					for _, win in ipairs(wins) do
						local ok, is_codediff = pcall(vim.api.nvim_win_get_var, win, "codediff")
						if ok and is_codediff then
							in_codediff = true
							break
						end
					end

					if in_codediff then
						-- Close the entire tabpage (CodeDiff opens in a new tab)
						vim.cmd("tabclose")
					else
						-- Try to close normally if not in a CodeDiff view
						vim.notify("No CodeDiff view open", vim.log.levels.INFO)
					end
				end,
				desc = "Close CodeDiff view",
			},
			-- NOTE: <leader>cx is not available in CodeDiff (no direct "choose delete" action)
			-- Use the conflict resolution keymaps instead: <leader>ct, <leader>co, <leader>cb, <leader>cx

			{ "<leader>cf", group = "(F)ile" },
			{ "<leader>cfH", "<Cmd>:CodeDiff file HEAD<CR>", desc = "diff (H)ead" },
			{
				"<leader>cfr",
				function()
					local ref = utils.get_git_ref()
					vim.cmd("CodeDiff file " .. ref)
				end,
				desc = "compare to ref",
			},
			{
				"<leader>cff",
				"<cmd>lua require('user.snacks.compare').find_file_from_root_to_compare_to()<CR>",
				desc = "(f)ile",
			},
			{ "<leader>cfh", "<Cmd>:CodeDiff history HEAD~20 %<CR>", desc = "(h)istory" },

			-- changes
			{ "<leader>cfc", "<cmd>CompareClipboard<cr>", desc = "compare (c)lipboard" },
		},

		visual = {
			{ "<leader>c", group = "Changes" },
			{ "<leader>cc", "<esc><cmd>CompareClipboardSelection<cr>", desc = "compare (c)lipboard" },
			{
				"<leader>ch",
			function()
				vim.cmd("CodeDiff history HEAD~20 %")
			end,
				desc = "(h)istory",
			},
		},

		shared = {},
	}
end

return M
