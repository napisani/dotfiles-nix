local builtin = require("telescope.builtin")
local utils = require("user.utils")
local common = require("user.telescope.common")

local os_sep = utils.path_sep
local action_set = require("telescope.actions.set")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local pickers = require("telescope.pickers")
local scan = require("plenary.scandir")
local actions = require("telescope.actions")

local M = {}
function M.live_grep_from_root(opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()
	local cmd_opts, dir_opts = common.constrain_to_scope()

	local vimgrep_arguments = utils.merge_list(common.content_ripgrep_base_cmd, {
		-- "--no-ignore", -- **This is the added flag**
		"--hidden", -- **Also this flag. The combination of the two is the same as `-uu`**
	})
	vimgrep_arguments = utils.merge_list(vimgrep_arguments, common.ignore_globs)
	vimgrep_arguments = utils.merge_list(vimgrep_arguments, cmd_opts)

	opts.vimgrep_arguments = vimgrep_arguments
	opts.search_dirs = opts.search_dirs or {}
	opts.search_dirs = utils.merge_list(opts.search_dirs, dir_opts)

	-- builtin.live_grep(opts)
	local finder = finders.new_async_job({
		command_generator = function(prompt)
			if not prompt or prompt == "" then
				return nil
			end

			local pieces = vim.split(prompt, "@@")
			local args = vim.deepcopy(vimgrep_arguments)
			if pieces[1] then
				-- grep search regex
				table.insert(args, "-e")
				table.insert(args, pieces[1])
			end

			if pieces[2] then
				-- glob search
				table.insert(args, "-g")
				table.insert(args, pieces[2])
			end

			return args
		end,
		entry_maker = make_entry.gen_from_vimgrep(opts),
		cwd = opts.cwd,
		search_dirs = opts.search_dirs,
	})

	pickers
		.new(opts, {
			debounce = 100,
			prompt_title = "Live Grep",
			finder = finder,
			previewer = conf.grep_previewer(opts),
			sorter = require("telescope.sorters").empty(),
		})
		:find()
end

function M.live_grep_qflist(opts)
	local list = vim.fn.getqflist({ all = true })
	if list == nil or list.items == nil or vim.tbl_isempty(list.items) then
		vim.notify("No items in quickfix list")
		return
	end
	local file_list = {}
	for _, item in ipairs(list.items) do
		if item.text ~= nil then
			table.insert(file_list, "--glob")
			table.insert(file_list, item.text)
		end
	end
	common.live_grep_static_file_list(opts, file_list)
end

M.live_grep_in_directory = function(opts)
	opts = opts or {}
	local data = {}
	scan.scan_dir(utils.get_root_dir(), {
		hidden = opts.hidden,
		only_dirs = true,
		respect_gitignore = opts.respect_gitignore,
		on_insert = function(entry)
			table.insert(data, entry .. os_sep)
		end,
	})
	table.insert(data, 1, "." .. os_sep)

	pickers
		.new(opts, {
			prompt_title = "Directory for Live Grep",
			finder = finders.new_table({ results = data, entry_maker = make_entry.gen_from_file(opts) }),
			previewer = conf.file_previewer(opts),
			sorter = conf.file_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				action_set.select:replace(function()
					local current_picker = action_state.get_current_picker(prompt_bufnr)
					local dirs = {}
					local selections = current_picker:get_multi_selection()
					if vim.tbl_isempty(selections) then
						table.insert(dirs, action_state.get_selected_entry().value)
					else
						for _, selection in ipairs(selections) do
							table.insert(dirs, selection.value)
						end
					end
					actions._close(prompt_bufnr, current_picker.initial_mode == "insert")
					builtin.live_grep({ search_dirs = dirs })
				end)
				return true
			end,
		})
		:find()
end

M.search_buffers = builtin.buffers
return M
