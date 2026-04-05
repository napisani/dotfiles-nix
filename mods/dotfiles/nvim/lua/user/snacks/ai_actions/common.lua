--- Shared utilities for AI action backends.
--
-- Centralises context formatting and capture logic so each backend
-- only needs to deal with its own transport/submission mechanics.

local M = {}

--- Ref styles used by context builders.
-- "at"       → @path:line
-- "markdown" → File: `path:line`
M.REF_STYLE_AT = "at"
M.REF_STYLE_MARKDOWN = "markdown"

--- Format a file + line reference string.
---@param ctx table { relative_path?, file_path?, line? }
---@param style string "at" | "markdown"
---@return string|nil  nil when there is nothing to format
function M.format_file_ref(ctx, style)
	local ref = ctx.relative_path or ctx.file_path or ""
	if ref == "" then
		return nil
	end
	local line_suffix = ctx.line and (":" .. ctx.line) or ""
	if style == M.REF_STYLE_MARKDOWN then
		return "File: `" .. ref .. line_suffix .. "`"
	end
	-- default: "at"
	return "@" .. ref .. line_suffix
end

--- Wrap a selection string in code fences with an optional heading label.
---@param selection string|nil
---@param style string "at" | "markdown"
---@param label string|nil
---@return string|nil  nil when selection is empty/nil
function M.format_selection(selection, style, label)
	if not selection or selection == "" then
		return nil
	end
	local prefix = ""
	if label and label ~= "" then
		prefix = label .. ":\n"
	end
	if style == M.REF_STYLE_MARKDOWN then
		return prefix .. "```\n" .. selection .. "\n```"
	end
	return prefix .. "```\n" .. selection .. "\n```"
end

--- Build a complete context message from file ref + selection + optional prompt.
---@param ctx table   { relative_path?, file_path?, line?, selection? }
---@param opts table? {
--- style?: string,
--- separator?: string,
--- prompt?: string,
--- prompt_label?: string|false,
--- selection_label?: string|false
--- }
---@return string      assembled message (may be "")
function M.build_context_message(ctx, opts)
	opts = opts or {}
	local style = opts.style or M.REF_STYLE_AT
	local sep = opts.separator or "\n\n"
	local selection_label = opts.selection_label
	if selection_label == nil then
		selection_label = "Selection"
	end
	local prompt_label = opts.prompt_label
	if prompt_label == nil then
		prompt_label = "Instruction"
	end

	local parts = {}

	local ref = M.format_file_ref(ctx, style)
	if ref then
		table.insert(parts, ref)
	end

	local sel = M.format_selection(ctx.selection, style, selection_label or nil)
	if sel then
		table.insert(parts, sel)
	end

	if opts.prompt and opts.prompt ~= "" then
		if prompt_label then
			table.insert(parts, prompt_label .. ":\n" .. opts.prompt)
		else
			table.insert(parts, opts.prompt)
		end
	end

	return table.concat(parts, sep)
end

--- Capture buffer / file / line / selection context from the current window.
--
-- Must be called synchronously before any async operation (e.g. Snacks.input)
-- because visual marks and cursor position are only reliable at call-time.
---@param mode string "n" | "v"
---@return table|nil ctx  nil when the buffer has no file name
function M.capture_context(mode)
	local bufnr = vim.api.nvim_get_current_buf()
	local file_path = vim.api.nvim_buf_get_name(bufnr)
	if file_path == "" then
		vim.notify("Current buffer has no file name", vim.log.levels.WARN)
		return nil
	end
	local relative_path = vim.fn.fnamemodify(file_path, ":.")
	local line = vim.api.nvim_win_get_cursor(0)[1]

	local selection = nil
	local start_line, end_line = line, line
	if mode == "v" then
		start_line = vim.fn.line("'<")
		end_line = vim.fn.line("'>")
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

	return {
		file_path = file_path,
		relative_path = relative_path,
		line = line,
		start_line = start_line,
		end_line = end_line,
		selection = selection,
	}
end

return M
