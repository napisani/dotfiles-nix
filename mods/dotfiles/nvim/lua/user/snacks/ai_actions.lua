local codecompanion = require("user.snacks.ai_actions.codecompanion")
local opencode = require("user.snacks.ai_actions.opencode")
local sidekick = require("user.snacks.ai_actions.sidekick")
local file_utils = require("user.utils.file_utils")

local M = {}

local function get_backend()
	if sidekick.is_plugin_open() then
		return sidekick
	end
	if opencode.is_plugin_open() then
		return opencode
	end
	return codecompanion
end

function M.is_plugin_open()
	return sidekick.is_plugin_open() or opencode.is_plugin_open() or codecompanion.is_plugin_open()
end

function M.send_file(file_info, opts)
	local backend = get_backend()
	return backend.send_file(file_info, opts)
end

function M.send_text(text, opts)
	local backend = get_backend()
	return backend.send_text(text, opts)
end

function M.open_convo_as_buffer(opts)
	local backend = get_backend()
	return backend.open_convo_as_buffer(opts)
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

	selection.file = file
	selection.cwd = selection.cwd or file_utils.get_root_dir()
	if selection.file:sub(1, 1) == "/" then
		selection.file_path = selection.file
	else
		selection.file_path = vim.fs.joinpath(selection.cwd, selection.file)
	end

	selection.relative_path = vim.fn.fnamemodify(selection.file_path, ":.")

	return selection
end

function M.add_current_buffer_to_chat()
	local file_path, bufnr = get_current_file_path()
	if not file_path then
		return
	end

	local file_info = {
		file_path = file_path,
		relative_path = vim.fn.fnamemodify(file_path, ":."),
		bufnr = bufnr,
	}

	M.send_file(file_info, { source = "current_buffer", insert_reference = true })
end

function M.add_file_to_chat(picker_fn, picker_opts)
	picker_opts = picker_opts or {}

	local function custom_confirm_action(picker)
		local Snacks = require("snacks")
		local active_pickers = Snacks.picker.get()
		if not active_pickers or #active_pickers == 0 then
			vim.notify("No active pickers found", vim.log.levels.ERROR)
			return
		end

		local active_picker = active_pickers[1]
		local selection = active_picker:selected({ fallback = true })
		active_picker:close()

		process_selection(selection, function(sel)
			local fi = coerce_and_validate_selection(sel)
			if fi then
				M.send_file(fi, { source = "picker", insert_reference = true })
			end
		end)
	end

	picker_opts.actions = picker_opts.actions or {}
	picker_opts.actions.custom_file_confirm = custom_confirm_action

	picker_opts.win = picker_opts.win or {}
	picker_opts.win.input = picker_opts.win.input or {}
	picker_opts.win.input.keys = picker_opts.win.input.keys or {}
	picker_opts.win.input.keys["<CR>"] = { "custom_file_confirm", mode = { "n", "i" } }

	picker_opts.win.list = picker_opts.win.list or {}
	picker_opts.win.list.keys = picker_opts.win.list.keys or {}
	picker_opts.win.list.keys["<CR>"] = "custom_file_confirm"

	picker_opts.multi_select = true

	picker_fn(picker_opts)
end

return M
