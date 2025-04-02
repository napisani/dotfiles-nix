local Snacks = require("snacks")
local scope = require("user.snacks.scope")

local find_opts = {
	cmd = "rg",
	hidden = true,
	ignored = false,
}
local M = {}

function M.find_path_files(opts)
	opts = opts or {}
	local all_opts = vim.tbl_extend("force", opts, {
		cmd = "rg",
		tree = true,
		hidden = true,
		ignored = false,
		follow_file = true,
		auto_close = true,
		layout = { preset = "my_horizontal_picker", preview = false },
	})
	return Snacks.picker.explorer(all_opts)
end

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
					table.insert(items, { text = v })
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
