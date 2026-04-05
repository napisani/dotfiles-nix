local codecompanion = require("user.snacks.ai_actions.codecompanion")
local agentic = require("user.snacks.ai_actions.agentic")
local wiremux = require("user.snacks.ai_actions.wiremux")
local common = require("user.snacks.ai_actions.common")

local M = {}
local MEMO_REGISTER = "5"
local MEMO_ENTRY_SEPARATOR = "\n\n---\n\n"

local function get_backend()
	if wiremux.is_plugin_open() then
		return wiremux
	end
	if agentic.is_snacks_backend() then
		return agentic
	end
	return codecompanion
end

-- Gather file/line/selection context, open a Snacks input for the user's
-- prompt, then dispatch to the active backend.
-- opts:
--   mode        "n" | "v"              (default "n")
--   ai_mode     "plan" | "build" | nil  passed to backend as a prompt hint
--   prompt_label string
function M.prompt_with_context(opts)
	opts = opts or {}
	local mode = opts.mode or "n"
	local ai_mode = opts.ai_mode -- nil | "plan" | "build"
	local prompt_label = opts.prompt_label or "Ask AI"

	-- Capture context immediately (before the async input window steals it)
	local ctx = common.capture_context(mode)
	if not ctx then
		return
	end
	ctx.mode = ai_mode

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

-- Send selected text + file path reference to the active backend's input
-- without submitting or prompting the user for additional input.
function M.stage_context()
	local ctx = common.capture_context("v")
	if not ctx then
		return
	end

	local backend = get_backend()
	backend.stage_context(ctx)
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
