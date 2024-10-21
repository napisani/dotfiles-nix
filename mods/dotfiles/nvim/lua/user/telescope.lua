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
	sorting_strategy = "ascending",
	layout_config = {
		prompt_position = "top",
		-- anchor = "N",
		width = 0.98,
		height = 0.70,
		preview_cutoff = 1, -- Always show preview
		preview_height = 0.3, -- 30% of the height for preview
	},
	layout_strategy = "vertical",
}

telescope.setup({
	defaults = vim.tbl_extend("force", {
		path_display = { "truncate" },
		prompt_prefix = "⮕ ",
		selection_caret = "➤ ",
		-- path_display = { "smart" },
		mappings = default_mappings,
	}, picker_layout),

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

-- to force certain files to be included per project
-- use a `.ignore` file at the root of the project and use
-- syntax like
-- !*.env.* # this will force .env files to be included in all searches

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
local previewers = require("telescope.previewers")
local putils = require("telescope.previewers.utils")

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
	local file_list = utils.git_changed_files().get_files()
	local arg_list = {}
	for _, file in ipairs(file_list) do
		table.insert(arg_list, "--glob")
		table.insert(arg_list, file)
	end

	live_grep_static_file_list(opts, arg_list)
end

function M.live_grep_git_changed_cmp_base_branch(opts)
	local base_branch = utils.get_primary_git_branch()
	local file_list = utils.git_changed_in_branch().get_files(base_branch)
	local arg_list = {}
	for _, file in ipairs(file_list) do
		table.insert(arg_list, "--glob")
		table.insert(arg_list, file)
	end
	live_grep_static_file_list(opts, arg_list)
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

	local cmd = { "git" }
	local args = utils.git_changed_files().get_git_args()
	for _, arg in ipairs(args) do
		table.insert(cmd, arg)
	end

	pickers
		.new(
			opts,
			vim.tbl_extend("force", picker_layout, {
				prompt_title = "Git changed files",
				previewer = conf.file_previewer(opts),
				finder = finders.new_oneshot_job(cmd, opts),
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
	local cmd = { "git" }
	local args = utils.git_changed_in_branch().get_git_args(base_branch)
	for _, arg in ipairs(args) do
		table.insert(cmd, arg)
	end

	pickers
		.new(
			opts,
			utils.table_merge(picker_layout, {
				prompt_title = "Git changed files compared to " .. base_branch,
				previewer = conf.file_previewer(opts),
				finder = finders.new_oneshot_job(cmd, opts),
				sorter = conf.file_sorter(opts),
			})
		)
		:find()
end

M.git_conflicts = function(opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()
	local cmd = { "git" }
	local args = utils.git_conflicted_files().get_git_args()
	for _, arg in ipairs(args) do
		table.insert(cmd, arg)
	end

	opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)
	pickers
		.new(
			opts,
			utils.table_merge(picker_layout, {
				prompt_title = "Git conflicts",
				previewer = conf.file_previewer(opts),
				finder = finders.new_oneshot_job(args, opts),
				sorter = conf.file_sorter(opts),
			})
		)
		:find()
end

local tmux_pane_id = nil
M.project_commands = function(opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()

	local cmd = {
		"animal-rescue",
		"--config",
		vim.env.HOME .. "/.config/pet/config.toml",
		"--snippets",
		"--search-path",
		opts.cwd,
	}

	local pet_data_raw = vim.fn.system(cmd)
	local json_snippets = vim.fn.json_decode(pet_data_raw)

	local to_preview = function(snippet)
		local content = {}
		table.insert(content, snippet.command)
		table.insert(content, "")
		table.insert(content, "# " .. snippet.description)
		return content
	end
	local entries = {}
	for _, snippet in ipairs(json_snippets["snippets"]) do
		local content = to_preview(snippet)
		table.insert(entries, {
			value = snippet.command,
			display = snippet.description,
			ordinal = snippet.description,
			content = content,
		})
	end
	opts.results = entries
	local project_commands = utils.get_project_config().commands
	for _, command in ipairs(project_commands) do
		local content = to_preview(command)
		table.insert(entries, {
			value = command.command,
			display = command.description,
			ordinal = command.description,
			content = content,
		})
	end

	local get_tmux_pane_id = function()
		if tmux_pane_id ~= nil then
			return tmux_pane_id
		end
		vim.fn.system("tmux display-panes")
		tmux_pane_id = vim.fn.input("Enter Pane ID: ")
		return tmux_pane_id
	end

	local custom_previewer = previewers.new_buffer_previewer({
		title = "Command Preview",
		get_buffer_by_name = function(_, entry)
			return entry.value
		end,

		define_preview = function(self, entry, status)
			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, entry.content)
			putils.regex_highlighter(self.state.bufnr, "bash")
		end,
	})

	return pickers
		.new(
			opts,
			utils.table_merge(picker_layout, {
				prompt_title = "Project Commands",
				previewer = custom_previewer,
				sorter = conf.file_sorter(opts),
				finder = finders.new_table({
					results = entries,
					entry_maker = function(entry)
						return entry
					end,
				}),

				attach_mappings = function(prompt_bufnr)
					action_set.select:replace(function()
						local selection = action_state.get_selected_entry()
						local pane_id = get_tmux_pane_id()
						local job = PlenaryJob:new({
							command = "tmux",
							args = {
								"send-keys",
								"-t",
								pane_id,
								selection.value,
								"Enter",
							},
						})
						job:start()
						actions.close(prompt_bufnr)
					end)
					return true
				end,
			})
		)
		:find()
end

return M
