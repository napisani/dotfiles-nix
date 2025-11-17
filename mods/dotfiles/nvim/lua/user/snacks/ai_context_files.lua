local codecompanion = require("codecompanion")
local config = require("codecompanion.config")
local util = require("codecompanion.utils")
local path = require("plenary.path")
local file_utils = require("user.utils.file_utils")

local M = {}

-- Shared helper functions
local function get_active_chat()
	local chat = codecompanion.last_chat()
	if not chat then
		vim.notify("No active CodeCompanion chat", vim.log.levels.ERROR)
		return nil
	end
	return chat
end

local function coerce_and_validate_selection(selection)
	if type(selection) ~= "table" then
		vim.notify("Invalid selection type: " .. type(selection), vim.log.levels.ERROR)
		return nil
	end
	if not selection.file or selection.file == "" then
		vim.notify("No file selected", vim.log.levels.ERROR)
		return nil
	end

	selection.cwd = selection.cwd or file_utils.get_root_dir()
	-- if the path starts with a slash, it is an absolute path
	if selection.file:sub(1, 1) == "/" then
		selection.file_path = selection.file
	else
		selection.file_path = vim.fs.joinpath(selection.cwd, selection.file)
	end

	selection.relative_path = vim.fn.fnamemodify(selection.file_path, ":.")

	return selection
end

-- Find a visible OpenCode window (returns win, buf, ft or nil)
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

local function add_file_to_codecompanion_chat_internal(file_info, chat, source)
	local fmt = string.format
	local file_path = file_info.file_path
	local relative_path = file_info.relative_path
	local bufnr = file_info.bufnr

	local context_path = file_path
	-- Calculate relative path from root directory for context
	-- local context_path = file_utils.get_relative_to_root(file_path)

	-- Get file content
	local content
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		-- Read from buffer (includes unsaved changes)
		content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
	else
		-- Read from disk
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

	-- Get filetype for syntax highlighting
	local ft
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		ft = vim.bo[bufnr].filetype
	end
	if not ft or ft == "" then
		ft = vim.filetype.match({ filename = file_path })
	end

	local id = "<file>" .. relative_path .. "</file>"

	-- Format the content with Markdown
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

	-- Add message to chat
	chat:add_message({
		role = config.constants.USER_ROLE,
		content = description or "",
	}, { reference = id, visible = false })

	-- Add file reference to context
	chat:add_context({ content = context_path, role = "user" }, source or "file_command", id)

	-- Notify user
	util.notify(fmt("Added the `%s` file to the chat", vim.fn.fnamemodify(relative_path, ":t")))

	return true
end

local function add_file_name_ref_to_codecompanion_chat(file_info, chat)
	-- Insert the name of the file into the chat buffer at the current cursor position
	if vim.api.nvim_get_current_buf() ~= chat.bufnr then
		return
	end

	local relative_path = file_info.relative_path
	vim.notify("Inserting file reference: " .. relative_path, vim.log.levels.DEBUG)

	-- insert the file name at the current cursor position
	vim.api.nvim_buf_set_lines(
		chat.bufnr,
		vim.api.nvim_win_get_cursor(0)[1],
		vim.api.nvim_win_get_cursor(0)[1],
		false,
		{ "`" .. relative_path .. "`" }
	)
end

-- Public functions
function M.add_current_buffer_to_chat()
	-- Prefer OpenCode if visible
	local win = select(1, find_opencode_window())
	if win then
		local bufnr = vim.api.nvim_get_current_buf()
		local file_path = vim.api.nvim_buf_get_name(bufnr)
		if file_path == "" then
			vim.notify("Current buffer has no file name", vim.log.levels.ERROR)
			return
		end
		local context_path = file_utils.get_relative_to_root(file_path)
		local opencode_context = require("opencode.context")
		require("opencode.ui.mention").mention(function(mention_cb)
			mention_cb(context_path)
			opencode_context.add_file(context_path)
		end)
		return
	end

	-- Fallback to CodeCompanion
	local chat = get_active_chat()
	if not chat then
		return
	end

	-- Get current buffer information
	local bufnr = vim.api.nvim_get_current_buf()
	local file_path = vim.api.nvim_buf_get_name(bufnr)
	if file_path == "" then
		vim.notify("Current buffer has no file name", vim.log.levels.ERROR)
		return
	end

	local file_info = { file_path = file_path, relative_path = vim.fn.fnamemodify(file_path, ":.") }
	-- Use current buffer number for accessing current content
	file_info.bufnr = bufnr

	if add_file_to_codecompanion_chat_internal(file_info, chat, "current_buffer") then
		add_file_name_ref_to_codecompanion_chat(file_info, chat)
	end
end

function M.add_file_to_chat(picker_fn, picker_opts)
	local win = select(1, find_opencode_window())
	picker_opts = picker_opts or {}

	local function add_with_opencode(selection)
		local ok, oc = pcall(require, "opencode.context")
		if not (ok and oc and type(oc.add_file) == "function") then
			vim.notify("OpenCode context not available", vim.log.levels.ERROR)
			return
		end
		local function add_one(sel)
			local fi = coerce_and_validate_selection(sel)
			if fi then
				oc.add_file(fi.file_path)
			end
		end
		if type(selection) == "table" and #selection > 0 then
			for _, s in ipairs(selection) do
				add_one(s)
			end
		else
			add_one(selection)
		end
	end

	-- Launch snacks.nvim picker
	local all_opts = vim.tbl_extend("force", picker_opts, {
		multi_select = true,
		confirm = function(picker)
			local selection = picker:selected({ fallback = true })
			picker:close()

			if win then
				add_with_opencode(selection)
				return
			end

			local chat = get_active_chat()
			if not chat then
				return
			end

			if type(selection) == "table" and #selection > 0 then
				for _, sel in ipairs(selection) do
					local fi = coerce_and_validate_selection(sel)
					if fi then
						add_file_to_codecompanion_chat_internal(fi, chat)
					end
				end
				for _, sel in ipairs(selection) do
					local fi = coerce_and_validate_selection(sel)
					if fi then
						add_file_name_ref_to_codecompanion_chat(fi, chat)
					end
				end
			else
				local fi = coerce_and_validate_selection(selection)
				if fi and add_file_to_codecompanion_chat_internal(fi, chat) then
					add_file_name_ref_to_codecompanion_chat(fi, chat)
				end
			end
		end,
	})

	picker_fn(all_opts)
end

return M
