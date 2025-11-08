local M = {}

function M.setup()
	local status_ok, gitsigns = pcall(require, "gitsigns")
	if not status_ok then
		vim.notify("gitsigns not found")
		return
	end

	gitsigns.setup({
		signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
		numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
		linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
		word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
		watch_gitdir = {
			interval = 1000,
			follow_files = true,
		},
		attach_to_untracked = true,
		current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
		current_line_blame_opts = {
			virt_text = true,
			virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
			delay = 1000,
			ignore_whitespace = false,
		},
		sign_priority = 6,
		update_debounce = 100,
		status_formatter = nil, -- Use default
		max_file_length = 40000,
		preview_config = {
			-- Options passed to nvim_open_win
			border = "single",
			style = "minimal",
			relative = "cursor",
			row = 0,
			col = 1,
		},
	})
end

function M.get_keymaps()
	local gitsigns = require("gitsigns")
	local compare = require("user.snacks.compare")

	return {
		normal = {},
		visual = {},

		shared = {
			{ "<leader>g", group = "Git" },
			{
				"<leader>gr",
				function()
					compare.establish_git_ref()
				end,
				desc = "set (r)ef",
			},

			{
				"<leader>gR",
				function()
					compare.establish_git_ref(true)
				end,
				desc = "set (R)ef commit",
			},

			{
				"<leader>gl",
				function()
					gitsigns.blame_line()
				end,
				desc = "Blame",
			},
			{
				"]g",
				function()
					gitsigns.next_hunk()
				end,
				desc = "Next Hunk",
			},
			{
				"[g",
				function()
					gitsigns.prev_hunk()
				end,
				desc = "Prev Hunk",
			},
		},
	}
end
-- test
return M
