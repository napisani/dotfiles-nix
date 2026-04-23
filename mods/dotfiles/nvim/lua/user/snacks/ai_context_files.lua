local file_utils = require("user.utils.file_utils")
local prompt_builder = require("user.prompt_builder")

local M = {}

local function get_relative_path_for_file(file_path)
	local root_dir = vim.fs.root(file_path, { ".git" }) or file_utils.get_root_dir()
	return file_utils.get_relative_to_root(file_path, root_dir)
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
		return
	end
	callback(selection)
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
	selection.relative_path = file_utils.get_relative_to_root(selection.file_path, selection.cwd)

	return selection
end

local function to_reference_item(file_info)
	if file_info.start_line and file_info.end_line then
		return {
			kind = "selection",
			relative_path = file_info.relative_path,
			start_line = file_info.start_line,
			end_line = file_info.end_line,
		}
	end

	return {
		kind = "file",
		relative_path = file_info.relative_path,
	}
end

local function get_picker_selection()
	local ok, Snacks = pcall(require, "snacks")
	if not ok then
		vim.notify("Snacks not available", vim.log.levels.ERROR)
		return nil
	end

	local active_pickers = Snacks.picker.get()
	if not active_pickers or #active_pickers == 0 then
		vim.notify("No active pickers found", vim.log.levels.ERROR)
		return nil
	end

	local active_picker = active_pickers[1]
	local selection = active_picker:selected({ fallback = true })
	active_picker:close()
	return selection
end

function M.add_current_buffer_to_chat()
	local file_path, bufnr = get_current_file_path()
	if not file_path then
		return
	end

	prompt_builder.append_file_info({
		file_path = file_path,
		relative_path = get_relative_path_for_file(file_path),
		bufnr = bufnr,
	})
end

--- [v] send `@path lines s-e` for the last visual line range
function M.add_visual_range_to_chat()
	local file_path, bufnr = get_current_file_path()
	if not file_path then
		return
	end
	local start_line = vim.fn.line("'<")
	local end_line = vim.fn.line("'>")
	if not start_line or not end_line then
		return
	end

	prompt_builder.append_file_info({
		file_path = file_path,
		relative_path = get_relative_path_for_file(file_path),
		bufnr = bufnr,
		start_line = start_line,
		end_line = end_line,
	})
end

function M.add_file_to_chat(picker_fn, picker_opts)
	picker_opts = picker_opts or {}

	local function custom_confirm_action()
		local selection = get_picker_selection()
		if not selection then
			return
		end

		local refs = {}
		process_selection(selection, function(sel)
			local file_info = coerce_and_validate_selection(sel)
			if file_info then
				table.insert(refs, to_reference_item(file_info))
			end
		end)

		if #refs == 0 then
			return
		end

		prompt_builder.append_references(refs)
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
