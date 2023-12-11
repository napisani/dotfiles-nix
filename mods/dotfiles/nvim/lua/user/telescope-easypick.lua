local status_ok, easypick = pcall(require, "easypick")
if not status_ok then
	vim.notify("telescope easypick not found")
	return
end

local utils = require("user.utils")
local base_branch = utils.get_primary_git_branch("main")
local rootDir = utils.get_root_dir()

local picker_layout = {
	theme = "dropdown",
	layout_config = {
		width = 0.98,
		height = 0.60,
	},
}

easypick.setup({
	pickers = {
		-- diff locally changed files
		{
			name = "git_changed_files",
			-- this will include unstaged files that do not match .gitignore as well
			command = "git status --porcelain -u | awk '{str = sprintf(\"%s/%s\", \"".. rootDir .."\", $2)} END {print str}'",
			previewer = easypick.previewers.default(),
			opts = require("telescope.themes").get_dropdown(picker_layout),
		},
		-- diff current branch with base_branch and show files that changed with respective diffs in preview
		{
			name = "git_changed_cmp_base_branch",
			command = "git diff --name-only $(git merge-base HEAD " .. base_branch .. " )",
			previewer = easypick.previewers.branch_diff({ base_branch = base_branch }),
			opts = require("telescope.themes").get_dropdown(picker_layout),
		},

		-- list files that have conflicts with diffs in preview
		{
			name = "git_conflicts",
			command = "git diff --name-only --diff-filter=U --relative ",
			previewer = easypick.previewers.file_diff(),
			opts = require("telescope.themes").get_dropdown(picker_layout),
		},
	},
})
