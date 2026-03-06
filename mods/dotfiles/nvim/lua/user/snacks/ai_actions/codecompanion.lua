local codecompanion = require("codecompanion")
local config = require("codecompanion.config")
local util = require("codecompanion.utils")
local path = require("plenary.path")
local common = require("user.snacks.ai_actions.common")

local M = {}

local function get_active_chat()
	local chat = codecompanion.last_chat()
	if not chat then
		vim.notify("No active CodeCompanion chat", vim.log.levels.ERROR)
		return nil
	end
	return chat
end

local function add_file_to_chat_internal(file_info, chat, source)
	local fmt = string.format
	local file_path = file_info.file_path
	local relative_path = file_info.relative_path
	local bufnr = file_info.bufnr

	local context_path = file_path

	local content
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
	else
		local ok, file_content = pcall(function()
			return path.new(file_path):read()
		end)
		if not ok or file_content == "" then
			vim.notify("Could not read the file: " .. file_path, vim.log.levels.WARN)
			return false
		end
		content = file_content
	end

	if content == "" then
		vim.notify("File is empty: " .. file_path, vim.log.levels.WARN)
		return false
	end

	local ft
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		ft = vim.bo[bufnr].filetype
	end
	if not ft or ft == "" then
		ft = vim.filetype.match({ filename = file_path })
	end

	local id = "<file>" .. relative_path .. "</file>"

	local buffer_info = bufnr and fmt(' buffer_number="%s"', bufnr) or ""
	local description = fmt(
		[[<attachment filepath="%s"%s>Here is the content from the file:
        
```%s
%s
```
</attachment>]],
		relative_path,
		buffer_info,
		ft or "",
		content
	)

	chat:add_message({
		role = config.constants.USER_ROLE,
		content = description or "",
	}, { reference = id, visible = false })

	chat:add_context({ content = context_path, role = "user" }, source or "file_command", id)

	util.notify(fmt("Added the `%s` file to the chat", vim.fn.fnamemodify(relative_path, ":t")))

	return true
end

local function add_file_name_ref_to_chat(file_info, chat)
	if vim.api.nvim_get_current_buf() ~= chat.bufnr then
		return
	end

	local relative_path = file_info.relative_path
	vim.notify("Inserting file reference: " .. relative_path, vim.log.levels.DEBUG)

	vim.api.nvim_buf_set_lines(
		chat.bufnr,
		vim.api.nvim_win_get_cursor(0)[1],
		vim.api.nvim_win_get_cursor(0)[1],
		false,
		{ "`" .. relative_path .. "`" }
	)
end

function M.is_plugin_open()
	return codecompanion.last_chat() ~= nil
end

function M.send_file(file_info, opts)
	local chat = get_active_chat()
	if not chat then
		return false
	end

	local source = opts and opts.source or nil
	local insert_reference = opts and opts.insert_reference or false

	local ok = add_file_to_chat_internal(file_info, chat, source)
	if ok and insert_reference then
		add_file_name_ref_to_chat(file_info, chat)
	end

	return ok
end

-- ctx: { file_path, relative_path, line, selection? }
-- For CodeCompanion we open a new chat and add the context as a message,
-- then add the user prompt as a second message so the LLM sees both.
function M.send_prompt_with_context(ctx, prompt)
	if not prompt or prompt == "" then
		return false
	end

	local full_message = common.build_context_message(ctx, {
		style = common.REF_STYLE_AT,
		prompt = prompt,
	})

	-- Open inline assistant pre-filled with the composed message
	vim.cmd("CodeCompanion " .. vim.fn.escape(full_message, " "))
	return true
end

function M.send_text(text, _opts)
	if not text or text == "" then
		return false
	end

	local chat = get_active_chat()
	if not chat then
		return false
	end

	chat:add_message({
		role = config.constants.USER_ROLE,
		content = text,
	})

	return true
end

-- Stage context (file ref + selection) into the chat without submitting.
function M.stage_context(ctx)
	local chat = codecompanion.last_chat()
	if not chat then
		-- Open a new chat to stage into
		vim.cmd("CodeCompanionChat")
		chat = codecompanion.last_chat()
	end
	if not chat then
		vim.notify("Could not open CodeCompanion chat", vim.log.levels.ERROR)
		return false
	end

	local message = common.build_context_message(ctx, {
		style = common.REF_STYLE_AT,
	})
	if message == "" then
		return false
	end

	-- Add as user message without triggering a response
	chat:add_message({
		role = config.constants.USER_ROLE,
		content = message,
	}, { visible = true })

	util.notify("Context staged in chat (not submitted)")
	return true
end

function M.open_convo_as_buffer()
	local chat = get_active_chat()
	if not chat then
		return false
	end

	if not (chat.bufnr and vim.api.nvim_buf_is_valid(chat.bufnr)) then
		vim.notify("CodeCompanion chat buffer is not available", vim.log.levels.ERROR)
		return false
	end

	vim.cmd("sbuffer " .. chat.bufnr)
	return true
end

return M
