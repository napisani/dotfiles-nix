local codecompanion = require("codecompanion")
local config = require("codecompanion.config")
local util = require("codecompanion.utils")
local path = require("plenary.path")
local file_utils = require("user.utils.file_utils")
local wiremux_actions = require("user.snacks.ai_actions.wiremux")

local M = {}

-- Load OpenCode modules (may be nil if not available)
local opencode_context = nil
local opencode_mention = nil
do
	local ok, oc = pcall(require, "opencode.context")
	if ok then
		opencode_context = oc
	end
	local ok_mention, mention = pcall(require, "opencode.ui.mention")
	if ok_mention then
		opencode_mention = mention
	end
end

-- Shared helper functions
local function get_active_chat()
	local chat = codecompanion.last_chat()
	if not chat then
		vim.notify("No active CodeCompanion chat", vim.log.levels.ERROR)
		return nil
	end
	return chat
end

local function get_current_file_path()
	local bufnr = vim.api.nvim_get_current_buf()
	local file_path = vim.api.nvim_buf_get_name(bufnr)
	if file_path == "" then
		vim.notify("Current buffer has no file name", vim.log.levels.ERROR)
		return nil, nil
	end
	return file_path, bufnr
end

-- Process selection array or single item with a callback
local function process_selection(selection, callback)
	if type(selection) == "table" and #selection > 0 then
		for _, sel in ipairs(selection) do
			callback(sel)
		end
	else
		callback(selection)
	end
end

local function coerce_and_validate_selection(selection)
	if type(selection) ~= "table" then
		vim.notify("Invalid selection type: " .. type(selection), vim.log.levels.ERROR)
		return nil
	end

	-- Normalize: try multiple possible field names from different pickers
	-- Priority: _path (Snacks internal) > file > path > filename
	local file = selection._path
		or selection.file
		or selection.path
		or selection.filename
		or (selection.item and (selection.item._path or selection.item.path or selection.item.file or selection.item.filename))

	if not file or file == "" then
		vim.notify(
			"No file found in selection. Keys: " .. table.concat(vim.tbl_keys(selection), ", "),
			vim.log.levels.ERROR
		)
		return nil
	end

	selection.file = file -- normalize to 'file' field
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
	local file_path, bufnr = get_current_file_path()
	if not file_path then
		return
	end

	-- Prefer OpenCode if visible
	local win = select(1, find_opencode_window())
	if win then
		if not (opencode_context and opencode_mention) then
			vim.notify("OpenCode modules not available", vim.log.levels.ERROR)
			return
		end
		local context_path = file_utils.get_relative_to_root(file_path)
		opencode_mention.mention(function(mention_cb)
			mention_cb(context_path)
			opencode_context.add_file(context_path)
		end)
		return
	end

	if wiremux_actions.is_plugin_open() then
		local file_info = {
			file_path = file_path,
			relative_path = vim.fn.fnamemodify(file_path, ":."),
			bufnr = bufnr,
		}
		if wiremux_actions.send_file(file_info, { source = "current_buffer" }) then
			return
		end
	end

	-- Fallback to CodeCompanion
	local chat = get_active_chat()
	if not chat then
		return
	end

	local file_info = {
		file_path = file_path,
		relative_path = vim.fn.fnamemodify(file_path, ":."),
		bufnr = bufnr,
	}

	if add_file_to_codecompanion_chat_internal(file_info, chat, "current_buffer") then
		add_file_name_ref_to_codecompanion_chat(file_info, chat)
	end
end

function M.add_file_to_chat(picker_fn, picker_opts)
	local win = select(1, find_opencode_window())
	picker_opts = picker_opts or {}

	-- Helper to add files to OpenCode
	local function add_with_opencode(selection)
		if not (opencode_context and opencode_mention) then
			vim.notify("OpenCode modules not available", vim.log.levels.ERROR)
			return
		end
		
		-- Collect all file paths
		local file_paths = {}
		process_selection(selection, function(sel)
			local fi = coerce_and_validate_selection(sel)
			if fi then
				local context_path = file_utils.get_relative_to_root(fi.file_path)
				table.insert(file_paths, context_path)
			end
		end)
		
		-- Add files to OpenCode context using the mention API
		opencode_mention.mention(function(mention_cb)
			for _, context_path in ipairs(file_paths) do
				mention_cb(context_path)
				opencode_context.add_file(context_path)
			end
		end)
	end

	local function add_with_wiremux(selection)
		if not wiremux_actions.is_plugin_open() then
			return false
		end
		local sent_any = false
		process_selection(selection, function(sel)
			local fi = coerce_and_validate_selection(sel)
			if fi and wiremux_actions.send_file(fi, { source = "picker" }) then
				sent_any = true
			end
		end)
		return sent_any
	end

	-- Helper to add files to CodeCompanion
	local function add_with_codecompanion(selection)
		local chat = get_active_chat()
		if not chat then
			return
		end

		process_selection(selection, function(sel)
			local fi = coerce_and_validate_selection(sel)
			if fi then
				if add_file_to_codecompanion_chat_internal(fi, chat) then
					add_file_name_ref_to_codecompanion_chat(fi, chat)
				end
			end
		end)
	end

	-- Custom confirm callback that handles multi-select
	local function custom_confirm_action(picker)
		-- Get the actual picker object from Snacks
		local Snacks = require("snacks")
		local active_pickers = Snacks.picker.get()
		if not active_pickers or #active_pickers == 0 then
			vim.notify("No active pickers found", vim.log.levels.ERROR)
			return
		end
		
		local active_picker = active_pickers[1]
		local selection = active_picker:selected({ fallback = true })
		active_picker:close()

		if win then
			add_with_opencode(selection)
		elseif wiremux_actions.is_plugin_open() then
			add_with_wiremux(selection)
		else
			add_with_codecompanion(selection)
		end
	end

	-- Register our custom action
	picker_opts.actions = picker_opts.actions or {}
	picker_opts.actions.custom_file_confirm = custom_confirm_action
	
	-- Override the confirm key to use our custom action
	picker_opts.win = picker_opts.win or {}
	picker_opts.win.input = picker_opts.win.input or {}
	picker_opts.win.input.keys = picker_opts.win.input.keys or {}
	picker_opts.win.input.keys["<CR>"] = { "custom_file_confirm", mode = { "n", "i" } }
	
	picker_opts.win.list = picker_opts.win.list or {}
	picker_opts.win.list.keys = picker_opts.win.list.keys or {}
	picker_opts.win.list.keys["<CR>"] = "custom_file_confirm"
	
	-- Enable multi-select
	picker_opts.multi_select = true

	-- Call the picker function
	picker_fn(picker_opts)
end

return M
