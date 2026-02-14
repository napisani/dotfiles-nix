local file_utils = require("user.utils.file_utils")

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

local function find_opencode_window()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		local ft = vim.bo[buf].filetype
		if ft == "opencode" or ft == "opencode_input" or ft == "opencode_output" then
			return win, buf, ft
		end
	end
	return nil
end

function M.is_plugin_open()
	if not (opencode_context and opencode_mention) then
		return false
	end
	return find_opencode_window() ~= nil
end

function M.send_file(file_info, _opts)
	if not (opencode_context and opencode_mention) then
		vim.notify("OpenCode modules not available", vim.log.levels.ERROR)
		return false
	end

	local context_path = file_utils.get_relative_to_root(file_info.file_path)
	opencode_mention.mention(function(mention_cb)
		mention_cb(context_path)
		opencode_context.add_file(context_path)
	end)

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

function M.open_convo_as_buffer()
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
