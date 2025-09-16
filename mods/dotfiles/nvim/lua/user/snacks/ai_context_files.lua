local codecompanion = require("codecompanion")
local config = require("codecompanion.config")
local util = require("codecompanion.utils")
local path = require("plenary.path")
local file_utils = require("user._file_utils")

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

local function add_file_to_chat_internal(file_info, chat, source)
	local fmt = string.format
	local file_path = file_info.file_path
	local relative_path = file_info.relative_path
	local bufnr = file_info.bufnr

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
	chat:add_context({ content = file_path, role = "user" }, source or "file_command", id)

	-- Notify user
	util.notify(fmt("Added the `%s` file to the chat", vim.fn.fnamemodify(relative_path, ":t")))

	return true
end

local function add_file_name_ref_to_chat(file_info, chat)
	-- Insert the name of the file into the chat buffer at the current cursor position
	if vim.api.nvim_get_current_buf() ~= chat.bufnr then
		return
	end

	local relative_path = file_info.relative_path

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

	local file_info = {
		file_path = file_path,
		relative_path = vim.fn.fnamemodify(file_path, ":."),
	}

	-- Use current buffer number for accessing current content
	file_info.bufnr = bufnr

	if add_file_to_chat_internal(file_info, chat, "current_buffer") then
		add_file_name_ref_to_chat(file_info, chat)
	end
end

function M.add_file_to_chat(picker_fn, picker_opts)
	local chat = get_active_chat()
	if not chat then
		return
	end

	picker_opts = picker_opts or {}

	-- Launch snacks.nvim picker
	local all_opts = vim.tbl_extend("force", picker_opts, {
		multi_select = true,
		confirm = function(picker)
			-- Get the selected items
			local selection = picker:selected({ fallback = true })
			picker:close()
			if type(selection) == "table" and #selection > 0 then
				-- Multiple files selected
				for _, selected_item in ipairs(selection) do
					local file_info = coerce_and_validate_selection(selected_item)
					if file_info then
						add_file_to_chat_internal(file_info, chat)
					end
				end

				for _, selected_item in ipairs(selection) do
					local file_info = coerce_and_validate_selection(selected_item)
					if file_info then
						add_file_name_ref_to_chat(file_info, chat)
					end
				end
			else
				-- Single file selected
				local file_info = coerce_and_validate_selection(selection)
				if file_info then
					if add_file_to_chat_internal(file_info, chat) then
						add_file_name_ref_to_chat(file_info, chat)
					end
				end
			end
		end,
	})

	picker_fn(all_opts)
end

return M
