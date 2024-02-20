local status_ok, telescope = pcall(require, "telescope")
if not status_ok then
	vim.notify("telescope not found")
	return
end

local plenary_ok, PlenaryJob = pcall(require, "plenary.job")
if not plenary_ok then
	vim.notify("plenary not found")
	return
end

local utils = require("user.utils")
local actions = require("telescope.actions")

local M = {}
local default_mappings = {
	i = {
		["<C-n>"] = actions.cycle_history_next,
		["<C-p>"] = actions.cycle_history_prev,
		["<C-j>"] = actions.move_selection_next,
		["<C-k>"] = actions.move_selection_previous,
		["<C-c>"] = actions.close,
		["<Down>"] = actions.move_selection_next,
		["<Up>"] = actions.move_selection_previous,
		["<CR>"] = actions.select_default,
		["<C-x>"] = actions.select_horizontal,
		["<C-v>"] = actions.select_vertical,
		["<C-t>"] = actions.select_tab,
		["<C-u>"] = actions.preview_scrolling_up,
		["<C-d>"] = actions.preview_scrolling_down,
		["<PageUp>"] = actions.results_scrolling_up,
		["<PageDown>"] = actions.results_scrolling_down,
		["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
		["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
		["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
		["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
		["<C-l>"] = actions.complete_tag,
		["<C-_>"] = actions.which_key, -- keys from pressing <C-/>
	},
	n = {
		["<esc>"] = actions.close,
		["dd"] = actions.delete_buffer,
		["<CR>"] = actions.select_default,
		["<C-x>"] = actions.select_horizontal,
		["<C-v>"] = actions.select_vertical,
		["<C-t>"] = actions.select_tab,
		["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
		["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
		["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
		["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
		["j"] = actions.move_selection_next,
		["k"] = actions.move_selection_previous,
		["n"] = actions.cycle_history_next,
		["p"] = actions.cycle_history_prev,
		["H"] = actions.move_to_top,
		["M"] = actions.move_to_middle,
		["L"] = actions.move_to_bottom,
		["<Down>"] = actions.move_selection_next,
		["<Up>"] = actions.move_selection_previous,
		["gg"] = actions.move_to_top,
		["G"] = actions.move_to_bottom,
		["<C-u>"] = actions.preview_scrolling_up,
		["<C-d>"] = actions.preview_scrolling_down,
		["<PageUp>"] = actions.results_scrolling_up,
		["<PageDown>"] = actions.results_scrolling_down,
		["?"] = actions.which_key,
	},
}

local picker_layout = {
	theme = "dropdown",
	layout_config = {
		-- prompt_position = "top",
		-- anchor = 'N',
		width = 0.98,
		height = 0.60,
	},
}
local adhoc_picker_layout = {
	theme = "dropdown",
	sorting_strategy = "ascending",
	layout_config = {
		prompt_position = "top",
		anchor = "N",
		width = 0.98,
		height = 0.60,
	},
	layout_strategy = "vertical",
}

telescope.setup({
	defaults = {
		path_display = { "truncate" },
		prompt_prefix = "⮕ ",
		selection_caret = "➤ ",
		-- path_display = { "smart" },
		mappings = default_mappings,
	},

	layout_config = {},
	pickers = {
		find_files = picker_layout,
		buffers = picker_layout,
		git_files = picker_layout,
		live_grep = picker_layout,
		-- Default configuration for builtin pickers goes here:
		-- picker_name = {
		--   picker_config_key = value,
		--   ...
		-- }
		-- Now the picker_config_key will be applied every time you call this
		-- builtin picker
	},
	extensions = {
		file_browser = {
			hidden = true,
			theme = "dropdown",
			layout_config = {
				width = 0.98,
				height = 0.60,
			},
			-- open to current buffer location
			-- path = "%:p:h",
			grouped = true,
			previewer = false,
			hijack_netrw = true,
		},
	},
})
telescope.load_extension("file_browser")
telescope.load_extension("luasnip")

local builtin = require("telescope.builtin")

local ignore_globs = {
	"--iglob",
	"!.git",
	"--iglob",
	"!node_modules",
	"--iglob",
	"!.mypy_cache",
	"--iglob",
	"!__pycache__",
	"--iglob",
	"!**.pyc",
	-- "--iglob",
	-- "!modules",
	"--iglob",
	"!target",
	"--iglob",
	"!.gradle",
	"--iglob",
	"!dist",
	"--iglob",
	"!.idea",
	"--iglob",
	"!.vscode",
	"--iglob",
	"!storybook-static",
	"--iglob",
	"!cypress/har-data",
	"--iglob",
	"!cypress/videos",
	"--iglob",
	"!cypress/screenshots",
	"--iglob",
	"!cypress/snapshots",
	"--iglob",
	"!malware-scanner",
	"--iglob",
	"!.coverage",
	"--iglob",
	"!android",
	"--iglob",
	"!ios",
	"--iglob",
	"!**.rlib",
}

local ripgrep_base_cmd = {
	"rg",
	"--color=never",
	"--no-heading",
}

local content_ripgrep_base_cmd = utils.merge_list(ripgrep_base_cmd, {
	"--with-filename",
	"--line-number",
	"--column",
	"--smart-case",
})

local function trimGitModificationIndicator(cmd_output)
	return cmd_output:match("[^%s]+$")
end

local neoscopes = require("user.neoscopes").neoscopes
local function constrain_to_scope()
	local success, scope = pcall(neoscopes.get_current_scope)
	if not success or not scope then
		-- utils.print('no current scope')
		return {}, {}
	end
	local find_command_opts = {}
	local search_dir_opts = {}
	local pattern = "^file:///"
	for _, dir_name in ipairs(scope.dirs) do
		if dir_name then
			if dir_name:find(pattern) ~= nil then
				table.insert(find_command_opts, "--glob")
				local file_name = dir_name:gsub(pattern, "")
				-- require('user.utils').print(file_name)
				-- table.insert(find_command_opts, string.gsub(dir_name, pattern, ""))
				table.insert(find_command_opts, file_name)
			else
				table.insert(search_dir_opts, dir_name)
			end
		end
	end
	for _, file_name in ipairs(scope.files) do
		if file_name then
			table.insert(find_command_opts, "--glob")
			-- require('user.utils').print('included' .. file_name)
			-- table.insert(find_command_opts, string.gsub(dir_name, pattern, ""))
			table.insert(find_command_opts, file_name)
		end
	end
	return find_command_opts, search_dir_opts
end

function M.find_files_from_root(opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()
	local cmd_opts, dir_opts = constrain_to_scope()

	local find_command = utils.merge_list(ripgrep_base_cmd, { "--files", "--hidden" })
	find_command = utils.merge_list(find_command, ignore_globs)
	find_command = utils.merge_list(find_command, cmd_opts)

	opts.find_command = find_command
	opts.search_dirs = opts.search_dirs or {}
	opts.search_dirs = utils.merge_list(opts.search_dirs, dir_opts)

	builtin.find_files(opts)
end

M.search_git_files = builtin.git_files
function M.live_grep_from_root(opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()
	local cmd_opts, dir_opts = constrain_to_scope()

	local vimgrep_arguments = utils.merge_list(content_ripgrep_base_cmd, {
		-- "--no-ignore", -- **This is the added flag**
		"--hidden", -- **Also this flag. The combination of the two is the same as `-uu`**
	})
	vimgrep_arguments = utils.merge_list(vimgrep_arguments, ignore_globs)
	vimgrep_arguments = utils.merge_list(vimgrep_arguments, cmd_opts)

	opts.vimgrep_arguments = vimgrep_arguments
	opts.search_dirs = opts.search_dirs or {}
	opts.search_dirs = utils.merge_list(opts.search_dirs, dir_opts)
	builtin.live_grep(opts)
end

local function live_grep_static_file_list(opts, file_list)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()
	local cmd_opts, dir_opts = constrain_to_scope()

	local vimgrep_arguments = utils.merge_list(content_ripgrep_base_cmd, {
		-- "--no-ignore", -- **This is the added flag**
		"--hidden", -- **Also this flag. The combination of the two is the same as `-uu`**
	})
	vimgrep_arguments = utils.merge_list(vimgrep_arguments, file_list)
	vimgrep_arguments = utils.merge_list(vimgrep_arguments, cmd_opts)
	opts.vimgrep_arguments = vimgrep_arguments

	opts.search_dirs = opts.search_dirs or {}
	opts.search_dirs = utils.merge_list(opts.search_dirs, dir_opts)
	builtin.live_grep(opts)
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
	live_grep_static_file_list(opts, file_list)
end

M.search_buffers = builtin.buffers

local os_sep = utils.path_sep
local action_set = require("telescope.actions.set")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local pickers = require("telescope.pickers")
local scan = require("plenary.scandir")

function M.find_file_from_root_to_compare_to()
	M.find_file_from_root_and_callback(function(prompt_bufnr)
		actions.close(prompt_bufnr)
		local selected_entry = action_state.get_selected_entry()
		if selected_entry ~= nil and selected_entry[1] ~= nil then
			local root_dir = utils.get_root_dir()
			local file_name = vim.fn.resolve(root_dir .. os_sep .. selected_entry[1])
			vim.cmd("vertical diffsplit " .. file_name)
		end
	end)
end

function M.find_file_from_root_and_callback(callback_fn)
	M.find_files_from_root({
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				callback_fn(prompt_bufnr)
			end)
			return true
		end,
	})
end

function M.live_grep_git_changed_files(opts)
	local file_list = {}
	PlenaryJob:new({
		command = "git",
		args = { "status", "--porcelain", "-u" },
		cwd = utils.get_root_dir(),
		on_exit = function(job)
			for _, cmd_output in ipairs(job:result()) do
				table.insert(file_list, "--glob")
				table.insert(file_list, trimGitModificationIndicator(cmd_output))
			end
		end,
	}):sync()

	live_grep_static_file_list(opts, file_list)
end

function M.live_grep_git_changed_cmp_base_branch(opts)
	local base_branch = utils.get_primary_git_branch()
	local file_list = {}
	PlenaryJob:new({
		command = "git",
		args = { "diff", "--name-only", base_branch .. "..HEAD" },
		cwd = utils.get_root_dir(),
		on_exit = function(job)
			for _, cmd_output in ipairs(job:result()) do
				table.insert(file_list, "--glob")
				table.insert(file_list, cmd_output)
			end
		end,
	}):sync()
	live_grep_static_file_list(opts, file_list)
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
					require("telescope.builtin").live_grep({ search_dirs = dirs })
				end)
				return true
			end,
		})
		:find()
end

M.git_changed_files = function(opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()

	local entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)
	opts.entry_maker = function(cmd_output)
		cmd_output = trimGitModificationIndicator(cmd_output)
		return entry_maker(cmd_output)
	end

	pickers
		.new(
			opts,
			utils.table_merge(adhoc_picker_layout, {
				prompt_title = "Git changed files",
				previewer = conf.file_previewer(opts),
				finder = finders.new_oneshot_job({
					"git",
					"status",
					"--porcelain",
					"-u",
				}, opts),
				sorter = conf.file_sorter(opts),
			})
		)
		:find()
end

M.git_changed_cmp_base_branch = function(opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()

	opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)

	local base_branch = utils.get_primary_git_branch()
	pickers
		.new(
			opts,
			utils.table_merge(adhoc_picker_layout, {
				prompt_title = "Git changed files compared to " .. base_branch,
				previewer = conf.file_previewer(opts),
				finder = finders.new_oneshot_job({
					"git",
					"diff",
					"--name-only",
					base_branch .. "..HEAD",
				}, opts),
				sorter = conf.file_sorter(opts),
			})
		)
		:find()
end

M.git_conflicts = function(opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()

	opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)
	pickers
		.new(
			opts,
			utils.table_merge(adhoc_picker_layout, {
				prompt_title = "Git conflicts",
				previewer = conf.file_previewer(opts),
				finder = finders.new_oneshot_job({
					"git",
					"diff",
					"--name-only",
					"--diff-filter=U",
					"--relative",
				}, opts),
				sorter = conf.file_sorter(opts),
			})
		)
		:find()
end

return M
