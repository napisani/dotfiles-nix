local file_utils = require("user.utils.file_utils")
local common = require("user.snacks.ai_actions.common")

local M = {}

local function to_reference_item(file_info)
	return {
		relative_path = file_info.relative_path,
		start_line = file_info.start_line,
		end_line = file_info.end_line,
	}
end

--- Format reference items and stage them in Vantage's composition buffer.
--- Reference formatting stays here rather than in Vantage: deciding which files
--- to reference (and the git/picker logic behind it) is config-side by design.
--- Uses blank-line separation so a run of refs reads as one list rather than as
--- separate `---`-delimited entries.
local function stage_reference_items(items)
	if not items or #items == 0 then
		return false
	end
	local payload = common.format_reference_payload({ items = items })
	if payload == "" then
		return false
	end
	return require("vantage").compose_append(payload, { separation = "blank" })
end

---@param file_info { file_path: string, relative_path: string, start_line?: number, end_line?: number, bufnr?: number }
local function stage_file_info(file_info)
	if not file_info or not file_info.relative_path or file_info.relative_path == "" then
		return
	end
	stage_reference_items({ to_reference_item(file_info) })
end

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

---Get a stable visual line range.
---When called from a visual mapping callback, '< and '> can be unset (0),
---so prefer the live visual anchor (`v`) and current cursor.
---@return integer|nil start_line
---@return integer|nil end_line
-- Vantage owns live visual-range detection; keeping a second implementation
-- here meant carrying the '< / '> fallback its docs call out as wrong.
local function get_visual_line_range()
	local ok, vantage = pcall(require, "vantage")
	if not ok then
		return nil, nil
	end
	return vantage.visual_range()
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
		or (
			selection.item
			and (selection.item._path or selection.item.path or selection.item.file or selection.item.filename)
		)

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


local function get_selection_from_picker(picker, fallback_item)
	if picker and type(picker.selected) == "function" then
		local ok, selection = pcall(function()
			return picker:selected({ fallback = true })
		end)
		if ok and type(selection) == "table" then
			if #selection > 0 then
				return selection
			end
			if selection._path or selection.file or selection.path or selection.filename or selection.item then
				return { selection }
			end
		end
	end

	if fallback_item then
		return { fallback_item }
	end

	return nil
end

local function close_picker(picker)
	if picker and type(picker.close) == "function" then
		picker:close()
	end
end

local function get_active_picker_selection()
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
	local selection = get_selection_from_picker(active_picker)
	close_picker(active_picker)
	return selection
end

function M.add_current_buffer_to_chat()
	local file_path, bufnr = get_current_file_path()
	if not file_path then
		return
	end

	stage_file_info({
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
	local start_line, end_line = get_visual_line_range()
	if not start_line or not end_line then
		vim.notify("No visual range found", vim.log.levels.WARN)
		return
	end

	stage_file_info({
		file_path = file_path,
		relative_path = get_relative_path_for_file(file_path),
		bufnr = bufnr,
		start_line = start_line,
		end_line = end_line,
	})
end

function M.append_file_selection_to_chat(selection)
	local refs = {}
	process_selection(selection, function(sel)
		local file_info = coerce_and_validate_selection(sel)
		if file_info then
			table.insert(refs, to_reference_item(file_info))
		end
	end)

	if #refs == 0 then
		return false
	end

	stage_reference_items(refs)
	return true
end

function M.append_picker_selection_to_chat(picker, fallback_item)
	local selection = get_selection_from_picker(picker, fallback_item)
	close_picker(picker)
	if not selection then
		return false
	end

	return M.append_file_selection_to_chat(selection)
end

function M.add_parent_path_file_to_chat()
	require("user.snacks.find_files").find_path_files({
		multi_select = true,
		confirm = function(picker, item)
			M.append_picker_selection_to_chat(picker, item)
		end,
	})
end

function M.add_file_to_chat(picker_fn, picker_opts)
	picker_opts = picker_opts or {}

	local function custom_confirm_action(picker, item)
		local selection
		if picker then
			selection = get_selection_from_picker(picker, item)
			close_picker(picker)
		else
			selection = get_active_picker_selection()
		end
		if not selection then
			return
		end

		M.append_file_selection_to_chat(selection)
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
