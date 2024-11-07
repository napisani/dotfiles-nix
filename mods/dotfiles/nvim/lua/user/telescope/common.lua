local actions = require("telescope.actions")
local utils = require("user.utils")
local builtin = require("telescope.builtin")

local M = {}

M.default_mappings = {
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

M.picker_layout = {
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

-- to force certain files to be included per project
-- use a `.ignore` file at the root of the project and use
-- syntax like
-- !*.env.* # this will force .env files to be included in all searches

M.ignore_globs = {
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

M.ripgrep_base_cmd = {
	"rg",
	"--color=never",
	"--no-heading",
}

M.content_ripgrep_base_cmd = utils.merge_list(M.ripgrep_base_cmd, {
	"--with-filename",
	"--line-number",
	"--column",
	"--smart-case",
})

function M.trimGitModificationIndicator(cmd_output)
	return cmd_output:match("[^%s]+$")
end

local neoscopes = require("user.neoscopes").neoscopes
function M.constrain_to_scope()
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

function M.live_grep_static_file_list(opts, file_list)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()
	local cmd_opts, dir_opts = M.constrain_to_scope()

	local vimgrep_arguments = utils.merge_list(M.content_ripgrep_base_cmd, {
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

return M
