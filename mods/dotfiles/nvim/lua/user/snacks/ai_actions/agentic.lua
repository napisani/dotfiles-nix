local common = require("user.snacks.ai_actions.common")

local M = {}

local function ensure_agentic()
	local ok, agentic = pcall(require, "agentic")
	if not ok then
		vim.notify("agentic not found", vim.log.levels.ERROR)
		return nil
	end
	return agentic
end

--- True when the Agentic plugin is available (lazy may load it on first use).
function M.is_snacks_backend()
	return pcall(require, "agentic")
end

--- @deprecated Use is_snacks_backend; kept for callers that meant "sidebar visible".
function M.is_plugin_open()
	local ok, SessionRegistry = pcall(require, "agentic.session_registry")
	if not ok then
		return false
	end
	local session = SessionRegistry.get_session_for_tab_page(nil)
	return session ~= nil and session.widget:is_open()
end

local function get_session()
	local ok, SessionRegistry = pcall(require, "agentic.session_registry")
	if not ok then
		return nil
	end
	return SessionRegistry.get_session_for_tab_page(nil)
end

--- Write text into the Agentic prompt buffer and focus it for editing.
local function set_prompt_text(message, notify_message)
	if not message or message == "" then
		return false
	end

	local agentic = ensure_agentic()
	if not agentic then
		return false
	end

	local SessionRegistry = require("agentic.session_registry")
	if not SessionRegistry.get_session_for_tab_page(nil) then
		vim.notify("Agentic could not start (check ACP provider configuration).", vim.log.levels.WARN)
		return false
	end

	local ok_open, err = pcall(agentic.open, { auto_add_to_context = false, focus_prompt = true })
	if not ok_open then
		vim.notify("agentic open failed: " .. tostring(err), vim.log.levels.ERROR)
		return false
	end

	vim.schedule(function()
		local session = get_session()
		if not session or not session.widget or not session.widget.buf_nrs then
			vim.notify("Agentic session not available", vim.log.levels.ERROR)
			return
		end

		local input_buf = session.widget.buf_nrs.input
		if not input_buf or not vim.api.nvim_buf_is_valid(input_buf) then
			vim.notify("Agentic input buffer not available", vim.log.levels.ERROR)
			return
		end

		local BufHelpers = require("agentic.utils.buf_helpers")
		local lines = vim.split(message, "\n", { plain = true })
		BufHelpers.with_modifiable(input_buf, function(buf)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		end)

		local input_win = session.widget.win_nrs.input
		if input_win and vim.api.nvim_win_is_valid(input_win) then
			vim.api.nvim_set_current_win(input_win)
		end
		vim.cmd("startinsert!")

		if notify_message then
			vim.notify(notify_message, vim.log.levels.INFO)
		end
	end)

	return true
end

local function build_prompt(ctx, prompt)
	local full_prompt = prompt
	if ctx.mode == "build" then
		full_prompt = prompt .. "\n\nMode hint: build. Use <S-Tab> in Agentic to switch modes before sending if needed."
	elseif ctx.mode == "plan" then
		full_prompt = prompt .. "\n\nMode hint: plan."
	end

	return common.build_context_message(ctx, {
		style = common.REF_STYLE_AT,
		prompt = full_prompt,
	})
end

function M.send_file(file_info, _opts)
	local agentic = ensure_agentic()
	if not agentic then
		return false
	end

	local SessionRegistry = require("agentic.session_registry")
	if not SessionRegistry.get_session_for_tab_page(nil) then
		return false
	end

	local path = vim.fn.fnamemodify(file_info.file_path, ":p")
	local ok, err = pcall(agentic.add_files_to_context, {
		files = { path },
		focus_prompt = true,
	})
	if not ok then
		vim.notify("Agentic add_files_to_context failed: " .. tostring(err), vim.log.levels.ERROR)
		return false
	end

	vim.notify(
		"Added file to Agentic context. Add a prompt and press <C-g> (or <CR>) to send.",
		vim.log.levels.INFO
	)
	return true
end

function M.send_prompt_with_context(ctx, prompt)
	local message = build_prompt(ctx, prompt)
	if message == "" then
		return false
	end

	return set_prompt_text(
		message,
		"Agentic prompt ready in input. Press <C-g> (or <CR>) to send."
	)
end

function M.send_text(text, _opts)
	return set_prompt_text(
		text,
		"Agentic prompt ready in input. Press <C-g> (or <CR>) to send."
	)
end

function M.stage_context(ctx)
	local message = common.build_context_message(ctx, {
		style = common.REF_STYLE_AT,
	})
	if message == "" then
		return false
	end

	return set_prompt_text(
		message,
		"Context staged in Agentic input. Press <C-g> (or <CR>) to send."
	)
end

function M.open_convo_as_buffer()
	return false
end

return M
