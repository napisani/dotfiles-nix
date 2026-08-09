local plenary_ok, PlenaryJob = pcall(require, "plenary.job")
if not plenary_ok then
	vim.notify("plenary not found")
	return
end

local project_utils = require("user.utils.project_utils")
local file_utils = require("user.utils.file_utils")
local git_ref = nil

local M = {}

function M.set_git_ref(ref)
	git_ref = ref
end

function M.get_git_ref()
	if git_ref == nil then
		M.set_git_ref(M.get_primary_git_branch())
	end
	return git_ref
end

function M.get_primary_git_branch()
	local override_branch = project_utils.get_project_config().branches.main
	if override_branch ~= nil then
		vim.notify("Using overridden primary git branch: " .. override_branch)
		return override_branch
	end
	local default_branch = "main"
	local status_ok, handle =
		pcall(io.popen, "git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'")
	if not status_ok then
		return default_branch
	end
	if handle ~= nil then
		local result = handle:read("*a")
		handle:close()
		if result == nil or result:match("fatal") or result == "" then
			return default_branch
		end
		result = result:gsub("\n", "")
		return result
	end
	return default_branch
end

local function trim_git_modification_indicator(cmd_output)
	return cmd_output:match("[^%s]+$")
end

-- Find the fork point of the current branch: the most recent commit shared
-- with any other local branch. Computed by merge-basing HEAD against every
-- other local branch, then picking whichever result is closest to HEAD
-- (i.e. the first of those SHAs encountered walking `git rev-list HEAD`).
-- This naturally prefers a stacked branch's immediate parent over a more
-- distant ancestor like `main`, with no branch-tracking metadata required.
function M.get_fork_point()
	local root = file_utils.get_root_dir()
	local function sys(cmd)
		return vim.system(cmd, { cwd = root, text = true }):wait()
	end

	local head = sys({ "git", "symbolic-ref", "--short", "-q", "HEAD" })
	local current_branch = head.code == 0 and head.stdout:gsub("\n", "") or nil

	local refs = sys({ "git", "for-each-ref", "--format=%(refname:short)", "refs/heads/" })
	if refs.code ~= 0 then
		return nil
	end

	local merge_bases = {}
	local seen = {}
	for branch in vim.gsplit(refs.stdout, "\n", { trimempty = true }) do
		if branch ~= current_branch then
			-- Skip branches stacked on top of HEAD (i.e. HEAD is their
			-- ancestor): merge-basing against a descendant branch trivially
			-- returns a commit at-or-behind HEAD, which would win the
			-- "closest to HEAD" ranking below and mask the real parent.
			local is_descendant = sys({ "git", "merge-base", "--is-ancestor", "HEAD", branch })
			if is_descendant.code ~= 0 then
				local mb = sys({ "git", "merge-base", "HEAD", branch })
				if mb.code == 0 then
					local sha = mb.stdout:gsub("\n", "")
					if sha ~= "" and not seen[sha] then
						seen[sha] = true
						table.insert(merge_bases, sha)
					end
				end
			end
		end
	end

	if #merge_bases == 0 then
		return nil
	end
	if #merge_bases == 1 then
		return merge_bases[1]
	end

	local rev_list = sys({ "git", "rev-list", "HEAD" })
	if rev_list.code ~= 0 then
		return merge_bases[1]
	end
	for sha in vim.gsplit(rev_list.stdout, "\n", { trimempty = true }) do
		if seen[sha] then
			return sha
		end
	end
	return merge_bases[1]
end

function M.git_conflicted_files()
	local get_git_args = function()
		return {
			"diff",
			"--name-only",
			"--diff-filter=U",
			"--relative",
		}
	end

	return {
		get_git_args = get_git_args,
	}
end

function M.git_changed_files()
	local get_git_args = function()
		return { "status", "--porcelain", "-u" }
	end

	local get_files = function()
		local file_list = {}
		local git_args = get_git_args()
		PlenaryJob:new({
			command = "git",
			args = git_args,
			cwd = file_utils.get_root_dir(),
			on_exit = function(job)
				for _, cmd_output in ipairs(job:result()) do
					table.insert(file_list, trim_git_modification_indicator(cmd_output))
				end
			end,
		}):sync()
		return file_list
	end

	return {
		get_git_args = get_git_args,
		get_files = get_files,
	}
end

function M.git_changed_in_branch()
	local get_git_args = function(compare_branch)
		local base_branch = compare_branch or M.get_primary_git_branch()
		return { "diff", "--name-only", base_branch .. "..HEAD" }
	end

	local get_files = function(compare_branch)
		local file_list = {}
		local git_args = get_git_args(compare_branch)

		PlenaryJob:new({
			command = "git",
			args = git_args,
			cwd = file_utils.get_root_dir(),
			on_exit = function(job)
				for _, cmd_output in ipairs(job:result()) do
					table.insert(file_list, cmd_output)
				end
			end,
		}):sync()

		return file_list
	end
	return {
		get_git_args = get_git_args,
		get_files = get_files,
	}
end

return M
