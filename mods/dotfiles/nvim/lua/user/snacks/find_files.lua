local Snacks = require("snacks")
local common = require("user.snacks.common")
local refresh = require("user.refresh")
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
		config = function(opts)
			local explorer_actions = require("snacks.explorer.actions").actions
			opts.actions = opts.actions or {}
			opts.actions.confirm = function(picker, item, action)
				if not item then
					return
				end

				if picker.input.filter.meta.searching or item.dir then
					return explorer_actions.confirm(picker, item, action)
				end

				common.open_file_keep_picker_focus(picker, item)
			end
			return opts
		end,
		win = {
			input = { keys = refresh.explorer_keys() },
			list = { keys = refresh.explorer_keys() },
			preview = { keys = refresh.explorer_keys() },
		},
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
		"-ap",
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
					if v ~= "." and v ~= "./" then
						table.insert(items, { text = v, file = file })
					end
				end

				local all_opts = vim.tbl_extend("force", opts, {
					source = "path files",
					items = items,
					format = "text",
					confirm = function(picker, item)
						if not item then
							if picker then
								picker:close()
							end
							return
						end

						if item.text:sub(-1) == "/" then
							-- its a directory - recurse
							if picker then
								picker:close()
							end
							local removed_slash = item.text:sub(1, -2)
							local new_start_path = parent_path .. "/" .. removed_slash
							M.find_path_files(vim.tbl_extend("force", opts, { start_path = new_start_path }))
						else
							-- its a file - open it
							local file_path = item.file or parent_path .. "/" .. item.text
							local file_exists = vim.fn.filereadable(file_path) == 1
							if file_exists then
								if opts.confirm then
									opts.confirm(picker, item)
								else
									if picker then
										picker:close()
									end
									vim.cmd("edit " .. vim.fn.fnameescape(file_path))
								end
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
