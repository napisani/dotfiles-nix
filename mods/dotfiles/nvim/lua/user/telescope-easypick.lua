local status_ok, easypick = pcall(require, "easypick")
if not status_ok then
  vim.notify("telescope easypick not found")
  return
end

local utils = require("user.utils")
local base_branch = utils.get_primary_git_branch("main")

easypick.setup({
	pickers = {
		-- diff locally changed files 
		{
			name = "git_changed_files",
			command = "git diff --name-only",
			previewer = easypick.previewers.default()
		},
		-- diff current branch with base_branch and show files that changed with respective diffs in preview
		{
			name = "git_changed_cmp_base_branch",
			command = "git diff --name-only $(git merge-base HEAD " .. base_branch .. " )",
			previewer = easypick.previewers.branch_diff({base_branch = base_branch})
		},

		-- list files that have conflicts with diffs in preview
		{
			name = "git_conflicts",
			command = "git diff --name-only --diff-filter=U --relative",
			previewer = easypick.previewers.file_diff()
		},
	}
})
