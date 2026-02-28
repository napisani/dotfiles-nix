local codecompanion = require("user.snacks.ai_actions.codecompanion")
local opencode = require("user.snacks.ai_actions.opencode")
local wiremux = require("user.snacks.ai_actions.wiremux")

local M = {}

local function get_backend()
	if opencode.is_plugin_open() then
		return opencode
	end
	if wiremux.is_plugin_open() then
		return wiremux
	end
	return codecompanion
end

-- Gather file/line/selection context, open a Snacks input for the user's
-- prompt, then dispatch to the active backend.
-- opts:
--   mode        "n" | "v"              (default "n")
--   ai_mode     "plan" | "build" | nil  passed to backend (opencode only)
--   prompt_label string
function M.prompt_with_context(opts)
	opts = opts or {}
	local mode = opts.mode or "n"
	local ai_mode = opts.ai_mode -- nil | "plan" | "build"
	local prompt_label = opts.prompt_label or "Ask AI"

	-- Capture context immediately (before the async input window steals it)
	local bufnr = vim.api.nvim_get_current_buf()
	local file_path = vim.api.nvim_buf_get_name(bufnr)
	if file_path == "" then
		vim.notify("Current buffer has no file name", vim.log.levels.WARN)
		return
	end
	local relative_path = vim.fn.fnamemodify(file_path, ":.")
	local line = vim.api.nvim_win_get_cursor(0)[1]

	-- Capture visual selection if in visual mode
	local selection = nil
	if mode == "v" then
		-- Marks '< and '> are set after leaving visual mode; we use them directly
		-- since which-key triggers keymaps after exiting visual.
		local start_line = vim.fn.line("'<")
		local end_line = vim.fn.line("'>")
		local start_col = vim.fn.col("'<") - 1
		local end_col = vim.fn.col("'>") -- nvim_buf_get_text end_col is exclusive

		local ok, lines = pcall(
			vim.api.nvim_buf_get_text,
			bufnr,
			start_line - 1,
			start_col,
			end_line - 1,
			end_col,
			{}
		)
		if ok and #lines > 0 then
			selection = table.concat(lines, "\n")
		end
	end

	local ctx = {
		file_path = file_path,
		relative_path = relative_path,
		line = line,
		selection = selection,
		mode = ai_mode,
	}

	local ok_snacks, Snacks = pcall(require, "snacks")
	if not ok_snacks then
		vim.notify("Snacks not available", vim.log.levels.ERROR)
		return
	end

	Snacks.input({ prompt = prompt_label }, function(value)
		if not value or value == "" then
			return
		end
		local backend = get_backend()
		backend.send_prompt_with_context(ctx, value)
	end)
end

return M
