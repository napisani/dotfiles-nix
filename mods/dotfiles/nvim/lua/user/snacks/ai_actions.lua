local wiremux = require("user.snacks.ai_actions.wiremux")
local common = require("user.snacks.ai_actions.common")

local M = {}
local MEMO_REGISTER = "5"
local MEMO_ENTRY_SEPARATOR = "\n\n---\n\n"

local function prompt_builder_buffer_nonempty(b)
	if not b or not vim.api.nvim_buf_is_valid(b) then
		return false
	end
	for _, l in ipairs(vim.api.nvim_buf_get_lines(b, 0, -1, false)) do
		if l and vim.trim(l) ~= "" then
			return true
		end
	end
	return false
end

-- Snacks.input (title = input_prompt) then append build_context_message (at-style
-- ref, optional selection fence, and body under body_label) to PromptBuilder. Same
-- code path for `<leader>am`, `<leader>ae`, and `<leader>a?`.
-- opts: mode, input_prompt (Snacks), body_label (build: "Label:\n" for typed text);
-- optional done_notify string
function M.append_snack_context_to_prompt_builder(opts)
	opts = opts or {}
	local mode = opts.mode or "n"
	local input_prompt = opts.input_prompt
	local body_label = opts.body_label
	if not input_prompt or input_prompt == "" or not body_label or body_label == "" then
		vim.notify("append_snack_context_to_prompt_builder: input_prompt and body_label are required", vim.log.levels.ERROR)
		return
	end

	local ctx = common.capture_context(mode)
	if not ctx then
		return
	end

	local ok_snacks, Snacks = pcall(require, "snacks")
	if not ok_snacks then
		vim.notify("Snacks not available", vim.log.levels.ERROR)
		return
	end

	Snacks.input({ prompt = input_prompt }, function(value)
		if not value or value == "" then
			return
		end
		local entry = common.build_context_message(ctx, {
			style = common.REF_STYLE_AT,
			prompt = value,
			prompt_label = body_label,
		})
		if entry == "" then
			return
		end
		local pb = require("user.prompt_builder")
		local pbb = pb.get_bufnr()
		if pbb and prompt_builder_buffer_nonempty(pbb) then
			pb.append_text("---\n\n" .. entry)
		else
			pb.append_text(entry)
		end
		vim.notify(opts.done_notify or "Appended to PromptBuilder", vim.log.levels.INFO)
	end)
end

-- Send selected text + file path reference to the active backend's input
-- without submitting or prompting the user for additional input.
function M.stage_context()
	local ctx = common.capture_context("v")
	if not ctx then
		return
	end

	wiremux.stage_context(ctx)
end

-- Like `<leader>ae` / `<leader>a?`, but with Snacks title + body `Instructions:`. Same path as the old register memoranda.
-- opts: mode "n" | "v" (default "n"); optional input_prompt, body_label (default "Instructions")
function M.append_memo_to_prompt_builder(opts)
	opts = opts or {}
	return M.append_snack_context_to_prompt_builder({
		mode = opts.mode or "n",
		input_prompt = opts.input_prompt or "Instructions",
		body_label = opts.body_label or "Instructions",
		done_notify = "Context appended to PromptBuilder",
	})
end

-- Append current context + user memo text to the dedicated memo register.
-- opts:
--   mode         "n" | "v"              (default "n")
--   prompt_label string
function M.append_context_to_register(opts)
	opts = opts or {}
	local mode = opts.mode or "n"
	local prompt_label = opts.prompt_label or "Add memo"

	local ctx = common.capture_context(mode)
	if not ctx then
		return
	end

	local ok_snacks, Snacks = pcall(require, "snacks")
	if not ok_snacks then
		vim.notify("Snacks not available", vim.log.levels.ERROR)
		return
	end

	Snacks.input({ prompt = prompt_label }, function(value)
		if not value or value == "" then
			return
		end

		local entry = common.build_context_message(ctx, {
			style = common.REF_STYLE_AT,
			prompt = value,
		})
		if entry == "" then
			return
		end

		local existing = vim.fn.getreg(MEMO_REGISTER)
		local updated = entry
		if existing ~= "" then
			updated = existing .. MEMO_ENTRY_SEPARATOR .. entry
		end

		vim.fn.setreg(MEMO_REGISTER, updated)
		vim.notify("Memo appended to register '" .. MEMO_REGISTER .. "'", vim.log.levels.INFO)
	end)
end

-- Paste memo register contents at the cursor.
function M.paste_context_register()
	local content = vim.fn.getreg(MEMO_REGISTER)
	if content == "" then
		vim.notify("Register '" .. MEMO_REGISTER .. "' is empty", vim.log.levels.WARN)
		return
	end

	vim.api.nvim_put(vim.split(content, "\n", { plain = true }), "c", true, true)
	M.clear_context_register()
end

-- Clear memo register contents.
function M.clear_context_register()
	vim.fn.setreg(MEMO_REGISTER, "")
	vim.notify("Cleared register '" .. MEMO_REGISTER .. "'", vim.log.levels.INFO)
end

return M
