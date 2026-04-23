--- Buffer-based staging area for Wiremux: collect @-refs and freeform text, then
--- send in one shot with <C-g>. Single global PromptBuilder buffer (horizontal split below, markdown).
---@module user.prompt_builder

--- Preferred height for the bottom prompt pane (capped, fraction of current editor height)
local function preferred_win_height()
	return math.max(10, math.min(32, math.floor(vim.o.lines * 0.32)))
end

local wiremux_actions = require("user.snacks.ai_actions.wiremux")

local M = {}

---@type integer|nil
local bufnr = nil

local AUG = "user_prompt_builder"

local function buf_is_prompt_builder(b)
	if not b or not vim.api.nvim_buf_is_valid(b) then
		return false
	end
	local ok, v = pcall(vim.api.nvim_buf_get_var, b, "prompt_builder")
	return ok and v
end

--- Find the PromptBuilder buffer if the handle was lost.
local function find_prompt_builder_buf()
	if bufnr and buf_is_prompt_builder(bufnr) then
		return bufnr
	end
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if buf_is_prompt_builder(b) then
			bufnr = b
			return b
		end
	end
	bufnr = nil
	return nil
end

local function win_for_buffer(b)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == b then
			return win
		end
	end
	return nil
end

--- Show the PromptBuilder buffer in a horizontal split below (reuse existing window if visible).
local function show_buffer(b)
	local w = win_for_buffer(b)
	if w then
		vim.api.nvim_set_current_win(w)
		return
	end
	-- Reattach hidden buffer to a new split below
	vim.cmd("rightbelow split")
	vim.api.nvim_win_set_buf(0, b)
	vim.api.nvim_win_set_height(0, preferred_win_height())
end

function M.get_bufnr()
	return find_prompt_builder_buf()
end

-- Create PromptBuilder in a lower split if missing, else focus the existing window or resplit.
function M.open_or_focus()
	local b = M.get_or_create_buffer()
	show_buffer(b)
end

---@param text string
local function buffer_has_visible_content(b)
	for _, l in ipairs(vim.api.nvim_buf_get_lines(b, 0, -1, false)) do
		if l and l ~= "" then
			return true
		end
	end
	return false
end

---@param text string
local function append_raw_text(b, text)
	if not text or text == "" then
		return
	end
	local chunk = tostring(text):gsub("%s+$", "\n")
	vim.api.nvim_buf_set_option(b, "modifiable", true)
	if not buffer_has_visible_content(b) then
		vim.api.nvim_buf_set_lines(b, 0, -1, false, vim.split(chunk, "\n", { plain = true }))
		return
	end
	-- insert a blank line between the prior block and this one
	local count = vim.api.nvim_buf_line_count(b)
	vim.api.nvim_buf_set_lines(b, count, count, true, vim.split("\n\n" .. chunk, "\n", { plain = true }))
end

---@param items table[] same shape as for wiremux `format_reference_payload` (kind/type + path, optional lines)
function M.append_references(items)
	if not items or #items == 0 then
		return
	end
	local text = wiremux_actions.format_reference_payload({ items = items })
	if text == "" then
		return
	end
	M.append_text(text)
end

---@param file_info { file_path: string, relative_path: string, start_line?: number, end_line?: number, bufnr?: number }
function M.append_file_info(file_info)
	if not file_info or not file_info.relative_path or file_info.relative_path == "" then
		return
	end
	if file_info.start_line and file_info.end_line then
		M.append_references({
			{
				kind = "selection",
				relative_path = file_info.relative_path,
				start_line = file_info.start_line,
				end_line = file_info.end_line,
			},
		})
		return
	end
	M.append_references({
		{ kind = "file", relative_path = file_info.relative_path },
	})
end

--- Append arbitrary text (e.g. preformatted @-refs).
function M.append_text(text)
	local b = M.get_or_create_buffer()
	append_raw_text(b, text)
	show_buffer(b)
end

---@return integer bufnr
function M.get_or_create_buffer()
	local existing = find_prompt_builder_buf()
	if existing then
		return existing
	end
	vim.cmd("rightbelow new")
	vim.api.nvim_win_set_height(0, preferred_win_height())
	local b = vim.api.nvim_get_current_buf()
	bufnr = b

	vim.bo[b].buflisted = false
	vim.bo[b].bufhidden = "wipe"
	vim.bo[b].buftype = "nofile"
	vim.bo[b].swapfile = false
	vim.bo[b].filetype = "markdown"
	vim.bo[b].fileencoding = "utf-8"
	vim.api.nvim_buf_set_name(b, "PromptBuilder")
	vim.api.nvim_buf_set_var(b, "prompt_builder", true)
	vim.api.nvim_buf_set_var(b, "prompt_builder_title", "PromptBuilder")

	-- Do not clobber a global; buffer-local
	vim.bo[b].modifiable = true
	vim.api.nvim_buf_set_lines(b, 0, -1, false, { "" })
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = b,
		group = vim.api.nvim_create_augroup(AUG .. "_buf", { clear = true }),
		callback = function()
			if bufnr == b then
				bufnr = nil
			end
		end,
		once = true,
	})
	M._set_buffer_keymaps(b)

	return b
end

function M._set_buffer_keymaps(b)
	vim.keymap.set({ "n", "i" }, "<C-g>", function()
		M._submit_and_wipe()
	end, { buffer = b, desc = "PromptBuilder: send to Wiremux and close" })
end

function M._submit_and_wipe()
	local b = find_prompt_builder_buf()
	if not b then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(b, 0, -1, false)
	local text = table.concat(lines, "\n")
	text = vim.trim(text)
	if text == "" then
		vim.notify("PromptBuilder is empty", vim.log.levels.WARN)
		return
	end

	local wiremux = require("user.plugins.ai.wiremux")
	local ok = wiremux.send_text(text .. "\n", { focus = true, submit = true })
	if not ok then
		return
	end

	local w = win_for_buffer(b)
	if w then
		vim.api.nvim_set_current_win(w)
		-- 'bwipeout' removes the window and the buffer; may fail for edge layouts
		pcall(vim.cmd, "bwipeout!")
	else
		pcall(vim.api.nvim_buf_delete, b, { force = true })
	end
	bufnr = nil
end

function M.setup()
	vim.api.nvim_create_augroup(AUG, { clear = true })
end

return M
