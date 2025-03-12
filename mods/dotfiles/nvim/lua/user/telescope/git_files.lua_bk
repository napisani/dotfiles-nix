local builtin = require("telescope.builtin")
local utils = require("user.utils")
local make_entry = require("telescope.make_entry")
local common = require("user.telescope.common")
local conf = require("telescope.config").values
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local M = {}

M.search_git_files = builtin.git_files
M.git_changed_files = function(opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()

	local entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)
	opts.entry_maker = function(cmd_output)
		cmd_output = common.trim_git_modification_indicator(cmd_output)
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
			vim.tbl_extend("force", common.picker_layout, {
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
			utils.table_merge(common.picker_layout, {
				prompt_title = "Git changed files compared to " .. base_branch,
				previewer = conf.file_previewer(opts),
        finder = finders.new_oneshot_job(cmd, opts), sorter =
          conf.file_sorter(opts),
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
			utils.table_merge(common.picker_layout, {
				prompt_title = "Git conflicts",
				previewer = conf.file_previewer(opts),
				finder = finders.new_oneshot_job(args, opts),
				sorter = conf.file_sorter(opts),
			})
		)
		:find()
end
return M
