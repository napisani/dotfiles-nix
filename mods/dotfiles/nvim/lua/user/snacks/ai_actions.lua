local codecompanion = require("user.snacks.ai_actions.codecompanion")
local opencode = require("user.snacks.ai_actions.opencode")
local wiremux = require("user.snacks.ai_actions.wiremux")
local common = require("user.snacks.ai_actions.common")

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

return M
