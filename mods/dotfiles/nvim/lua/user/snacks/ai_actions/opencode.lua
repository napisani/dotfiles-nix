local file_utils = require("user.utils.file_utils")
local common = require("user.snacks.ai_actions.common")

local M = {}

local opencode_context = nil
local opencode_mention = nil
local opencode_api = nil
local opencode_state = nil
do
	local ok, oc = pcall(require, "opencode.context")
	if ok then
		opencode_context = oc
	end
	local ok_mention, mention = pcall(require, "opencode.ui.mention")
	if ok_mention then
		opencode_mention = mention
	end
	local ok_api, api = pcall(require, "opencode.api")
	if ok_api then
		opencode_api = api
	end
	local ok_state, state = pcall(require, "opencode.state")
	if ok_state then
		opencode_state = state
	end
end

-- Returns true when the opencode server is running and has an active session
-- for the current working directory.  Does NOT require the UI windows to be
-- visible — the server may be running in the background on another tab.
function M.is_plugin_open()
	if not (opencode_context and opencode_mention) then
		return false
	end
	if not opencode_state then
		return false
	end
	-- Server must be up
	if not (opencode_state.opencode_server and opencode_state.opencode_server:is_running()) then
		return false
	end
	-- Must be the same working directory that opencode was started in
	local cwd = vim.fn.getcwd()
	if opencode_state.current_cwd and opencode_state.current_cwd ~= cwd then
		return false
	end
	-- Must have an active session (conversation exists)
	return opencode_state.active_session ~= nil
end

function M.send_file(file_info, _opts)
	if not (opencode_context and opencode_mention) then
		vim.notify("OpenCode modules not available", vim.log.levels.ERROR)
		return false
	end

	-- Ensure the UI is open so the user sees the file reference land
	if opencode_api and not (opencode_state and opencode_state.windows) then
		opencode_api.open({ focus = "input" })
	end

	local context_path = file_utils.get_relative_to_root(file_info.file_path)
	opencode_mention.mention(function(mention_cb)
		mention_cb(context_path)
		opencode_context.add_file(context_path)
	end)

	return true
end

-- ctx: { file_path, relative_path, line, selection?, mode? }
-- mode: "plan" | "build" | nil  — switches opencode agent before sending.
-- Builds a message with file reference + optional selection + prompt, then runs it.
function M.send_prompt_with_context(ctx, prompt)
	if not opencode_api then
		vim.notify("OpenCode API not available", vim.log.levels.ERROR)
		return false
	end

	local message = common.build_context_message(ctx, {
		style = common.REF_STYLE_AT,
		separator = "\n",
		prompt = prompt,
	})
	if message == "" then
		return false
	end

	-- Ensure UI is open
	if opencode_api and not (opencode_state and opencode_state.windows) then
		opencode_api.open({ focus = "input" })
	end

	local function do_run()
		opencode_api.run(message, { new_session = false, focus = "output" })
	end

	-- Switch mode first if requested, then send
	if ctx.mode then
		local ok_core, core = pcall(require, "opencode.core")
		if ok_core and type(core.switch_to_mode) == "function" then
			local ok_switch, mode_promise = pcall(core.switch_to_mode, ctx.mode)
			if ok_switch and type(mode_promise) == "table" and mode_promise.next then
				mode_promise:next(function()
					vim.schedule(do_run)
				end):catch(function(err)
					vim.notify("opencode mode switch failed: " .. tostring(err), vim.log.levels.WARN)
					do_run()
				end)
				return true
			end
		end
		-- switch_to_mode unavailable or failed — fall through and send anyway
	end

	do_run()
	return true
end

function M.send_text(text, _opts)
	if not text or text == "" then
		return false
	end
	if not opencode_api then
		vim.notify("OpenCode API not available", vim.log.levels.ERROR)
		return false
	end

	opencode_api.run(text, { new_session = false, focus = "output" })
	return true
end

-- Stage context (file ref + selection) into the input buffer without submitting.
function M.stage_context(ctx)
	if not opencode_api then
		vim.notify("OpenCode API not available", vim.log.levels.ERROR)
		return false
	end

	-- Ensure UI is open
	if not (opencode_state and opencode_state.windows) then
		opencode_api.open({ focus = "input" })
	end

	local message = common.build_context_message(ctx, {
		style = common.REF_STYLE_AT,
		separator = "\n",
	})
	if message == "" then
		return false
	end

	-- Write into the input buffer without submitting
	vim.schedule(function()
		local windows = opencode_state and opencode_state.windows
		if not windows or not windows.input_buf or not vim.api.nvim_buf_is_valid(windows.input_buf) then
			vim.notify("OpenCode input buffer not available", vim.log.levels.WARN)
			return
		end

		local lines = vim.split(message, "\n")
		-- Append to existing content
		local existing = vim.api.nvim_buf_get_lines(windows.input_buf, 0, -1, false)
		if #existing == 1 and existing[1] == "" then
			vim.api.nvim_buf_set_lines(windows.input_buf, 0, -1, false, lines)
		else
			vim.list_extend(existing, lines)
			vim.api.nvim_buf_set_lines(windows.input_buf, 0, -1, false, existing)
		end

		-- Focus the input window
		if windows.input_win and vim.api.nvim_win_is_valid(windows.input_win) then
			vim.api.nvim_set_current_win(windows.input_win)
		end
	end)

	return true
end

function M.open_convo_as_buffer(_opts)
	if not opencode_api then
		vim.notify("OpenCode API not available", vim.log.levels.ERROR)
		return false
	end

	local output_buf = opencode_state
		and opencode_state.windows
		and opencode_state.windows.output_buf
		or nil

	if not output_buf or not vim.api.nvim_buf_is_valid(output_buf) then
		opencode_api.open_output()
		output_buf = opencode_state
			and opencode_state.windows
			and opencode_state.windows.output_buf
			or nil
	end

	if not output_buf or not vim.api.nvim_buf_is_valid(output_buf) then
		vim.notify("OpenCode output buffer is not available", vim.log.levels.ERROR)
		return false
	end

	vim.cmd("sbuffer " .. output_buf)
	return true
end

return M
