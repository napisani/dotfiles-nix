local status_ok, telescope = pcall(require, "telescope")
if not status_ok then
	return
end

local M = {}
local utils = require("user.utils")
local rooter = require("user.nvim-rooter")
local actions = require("telescope.actions")
local picker_layout = {
	theme = "dropdown",
	layout_config = {
		width = 0.98,
		height = 0.60,
	},
}
telescope.setup({
	defaults = {
		path_display = { "truncate" },
		prompt_prefix = "⮕ ",
		selection_caret = "➤ ",
		-- path_display = { "smart" },
		mappings = {
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
		},
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
		-- Your extension configuration goes here:
		-- extension_name = {
		--   extension_config_key = value,
		-- }
		-- please take a look at the readme of the extension you want to configure
	},
})
telescope.load_extension("file_browser")
telescope.load_extension('luasnip')

local builtin = require("telescope.builtin")

local root_dir = require("user.nvim-rooter").get_root_dir()
local ignore_globs = {}
-- local ignore_globs = require("nvim-search-rules").get_ignore_globs_as_rg_args({
-- 	ignore_from_files = { ".gitignore", ".nvimignore" },
--   additional_ignore_globs = { "node_modules", ".git", "dist", ".idea", ".vscode" },
-- 	root_dir = root_dir
-- })
-- local ignore_globs = {
-- 	"--iglob",
-- 	"!.git",
-- 	"--iglob",
-- 	"!node_modules",
-- 	"--iglob",
-- 	"!.mypy_cache",
-- 	"--iglob",
-- 	"!__pycache__",
-- 	"--iglob",
-- 	"!**.pyc",
-- 	"--iglob",
-- 	"!modules",
-- 	"--iglob",
-- 	"!target",
-- 	"--iglob",
-- 	"!.gradle",
-- 	"--iglob",
-- 	"!dist",
-- 	"--iglob",
-- 	"!.idea",
-- 	"--iglob",
-- 	"!.vscode",
-- 	"--iglob",
-- 	"!storybook-static",
-- 	"--iglob",
-- 	"!cypress/har-data",
-- 	"--iglob",
-- 	"!cypress/videos",
-- 	"--iglob",
-- 	"!cypress/screenshots",
-- 	"--iglob",
-- 	"!cypress/snapshots",
-- 	"--iglob",
-- 	"!malware-scanner",
-- 	"--iglob",
-- 	"!.coverage",
-- 	"--iglob",
-- 	"!android",
-- 	"--iglob",
-- 	"!ios",
-- 	"--iglob",
-- 	"!**.rlib",
-- }
-- local rooter = require("nvim-rooter")
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
	-- local cwd = rooter.get_root()
	-- if cwd ~= nil then
	-- 	opts.cwd = cwd
	-- else
	-- 	opts.cwd = vim.fn.getcwd()
	-- end
	opts.cwd = rooter.get_root_dir()
	local cmd_opts, dir_opts = constrain_to_scope()
	opts.find_command = utils.table_merge(
		utils.table_merge({
			"rg",
			"--files",
			-- '--iglob', 'config.local.json',
			-- '--iglob', '.env.*',
			"--hidden",
			-- "--no-ignore", -- **This is the added flag**
		}, ignore_globs),
		cmd_opts
	)
	opts.search_dirs = opts.search_dirs or {}
	opts.search_dirs = utils.table_merge(opts.search_dirs, dir_opts)

	-- utils.print(opts.find_command)
	builtin.find_files(opts)
end

M.search_git_files = builtin.git_files
vim.keymap.set("n", "<C-S-R>", M.find_files_from_root, {})
vim.keymap.set("n", "<C-S-T>", builtin.git_files, {})
vim.keymap.set("n", "<C-S-P>", ":Telescope file_browser path=%:p:h<CR>", {})
function M.live_grep_from_root(opts)
	opts = opts or {}
	-- local cwd = require("nvim-rooter").get_root()
	-- if cwd ~= nil then
	-- 	opts.cwd = cwd
	-- end
	opts.cwd = rooter.get_root_dir()
	local cmd_opts, dir_opts = constrain_to_scope()
	opts.vimgrep_arguments = utils.table_merge(
		utils.table_merge({
			"rg",
			"--color=never",
			"--no-heading",
			"--with-filename",
			"--line-number",
			"--column",
			"--smart-case",
			-- "--no-ignore", -- **This is the added flag**
			"--hidden", -- **Also this flag. The combination of the two is the same as `-uu`**
		}, ignore_globs),
		cmd_opts
	)

	opts.search_dirs = opts.search_dirs or {}
	opts.search_dirs = utils.table_merge(opts.search_dirs, dir_opts)
	-- utils.print(opts)
	-- vim.notify(opts)
	builtin.live_grep(opts)
end

vim.keymap.set("n", "<C-S-H>", M.live_grep_from_root, {})
M.search_buffers = builtin.buffers
vim.keymap.set("n", "<C-S-E>", builtin.buffers, {})
--vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
--vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

-- live_grep_in_directory propmpt
local Path = require("plenary.path")
local action_set = require("telescope.actions.set")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local os_sep = Path.path.sep
local pickers = require("telescope.pickers")
local scan = require("plenary.scandir")

M.live_grep_in_directory = function(opts)
	opts = opts or {}
	local data = {}
	scan.scan_dir(vim.loop.cwd(), {
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
			prompt_title = "Folders for Live Grep",
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

return M
