local Snacks = require("snacks")
local scope = require("user.snacks.scope")

local find_opts = {
	cmd = "rg",
	hidden = true,
	ignored = false,
}
local M = {}

function M.find_files_from_root(opts)
	opts = opts or {}
	local all_opts = vim.tbl_extend("force", opts, find_opts)
	all_opts = scope.apply_scopes_to_rg_picker(all_opts)
	return Snacks.picker.files(all_opts)
end

M.toggle_explorer_tree = function()
	Snacks.picker.explorer({
		cmd = "rg",
		tree = true,
		follow_file = true,
		auto_close = false,
		hidden = true,
		ignored = false,
		layout = { preset = "sidebar", preview = false },
	})
end

function M.find_path_files(opts)
	opts = opts or {}
	local parent_path = opts.start_path
	if not parent_path then
		local current_buffer = vim.api.nvim_get_current_buf()
		local current_file = vim.api.nvim_buf_get_name(current_buffer)
		parent_path = vim.fn.fnamemodify(current_file, ":h")
	else
		opts.start_path = nil
	end

	local find_command = {
		"ls",
		"-Ap",
		"--color=never",
		parent_path,
	}

	vim.fn.jobstart(find_command, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				local filtered = vim.tbl_filter(function(el)
					return el ~= ""
				end, data)

				local items = {}
				for _, v in ipairs(filtered) do
					local file = parent_path .. "/" .. v
					table.insert(items, { text = v, file = file })
				end

				local all_opts = vim.tbl_extend("force", opts, {
					source = "path files",
					items = items,
					format = "text",
					confirm = function(picker, item)
						picker:close()
						if item.text:sub(-1) == "/" then
							-- its a directory - recurse
							local removed_slash = item.text:sub(1, -2)
							local new_start_path = parent_path .. "/" .. removed_slash
							M.find_path_files(vim.tbl_extend("force", opts, { start_path = new_start_path }))
						else
							-- its a file - open it
							local file_path = parent_path .. "/" .. item.text
							local file_exists = vim.fn.filereadable(file_path) == 1
							if file_exists then
								vim.cmd("edit " .. file_path)
							else
								vim.notify("File does not exist: " .. file_path, vim.log.levels.ERROR)
							end
						end
					end,
				})

				Snacks.picker.pick(all_opts)
			end
		end,
	})
end

function M.find_directories_from_root(on_select, opts)
	opts = opts or {}
	local find_command = {
		"fd",
		"--type",
		"d",
		"--color",
		"never",
	}

	vim.fn.jobstart(find_command, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				local filtered = vim.tbl_filter(function(el)
					return el ~= ""
				end, data)

				local items = {}
				for _, v in ipairs(filtered) do
					table.insert(items, { text = v, file = v })
				end

				local all_opts = vim.tbl_extend("force", opts, {
					source = "directories",
					items = items,
					format = "text",
					confirm = function(picker, item)
						picker:close()
						if on_select then
							on_select(item)
						end
					end,
				})

				Snacks.picker.pick(all_opts)
			end
		end,
	})
end

function M.pick_scopes(opts)
	M.find_directories_from_root(function(item)
		scope.add_scope(item.text)
	end, opts)
end
return M
