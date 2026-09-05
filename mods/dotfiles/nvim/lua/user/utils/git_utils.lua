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

-- Find the reference commit for "everything this branch adds": the fork point
-- from the branch's immediate stack parent when it's stacked, otherwise the
-- fork point from the trunk. Pure git — no branch-tracking metadata.
--
-- The hard part is that in the commit graph a *diverged parent* and a
-- *diverged child* are the same shape. Both share history with HEAD and then
-- differ, so merge-basing HEAD against every branch and taking whichever
-- result sits closest to HEAD (what this used to do) picks children and
-- siblings just as happily as parents. When it picked a child, the fork point
-- landed inside HEAD's own commits and the diff collapsed to the last commit
-- or two — the "sometimes doesn't include any changes" symptom. Divergence is
-- the normal state of a stack: rebase the child, then move the parent, and the
-- child no longer contains the parent's tip.
--
-- What actually separates them is distance from the trunk: a parent has fewer
-- commits since the trunk fork than HEAD does, a child has more. So candidates
-- are filtered by:
--   * not containing HEAD          — excludes children that haven't diverged
--   * closer to the trunk than HEAD — excludes children that have
--   * merge base strictly past the trunk fork — excludes siblings, which fork
--     from the trunk at the same commit rather than from this branch
-- and the winner is the one whose merge base sits deepest, i.e. the immediate
-- parent rather than a grandparent.
--
-- `git branch --contains <trunk fork>` also keeps this fast by pruning to the
-- stack region up front: 13 candidates instead of every local branch, which on
-- a repo with 151 of them is the difference between ~0.4s and ~5s of blocking
-- subprocesses.
--
-- Returns (sha, label) where label describes what was found, for the caller's
-- notification. Returns nil when the trunk fork can't be resolved at all.
function M.get_fork_point()
	local root = file_utils.get_root_dir()
	local function sys(cmd)
		return vim.system(cmd, { cwd = root, text = true }):wait()
	end
	local function out(res)
		return res.code == 0 and vim.trim(res.stdout) or nil
	end
	local function count(range)
		return tonumber(out(sys({ "git", "rev-list", "--count", range })) or "") or 0
	end

	-- The trunk may only exist as a remote ref (a fresh clone that never
	-- checked out main), so fall back to origin/<trunk> before giving up.
	local trunk = M.get_primary_git_branch()
	local trunk_fork = out(sys({ "git", "merge-base", "HEAD", trunk }))
	if not trunk_fork then
		trunk = "origin/" .. trunk
		trunk_fork = out(sys({ "git", "merge-base", "HEAD", trunk }))
	end
	if not trunk_fork or trunk_fork == "" then
		return nil
	end

	-- Detached HEAD (mid-rebase) has no branch name; nothing to exclude by
	-- name, and any branch sitting at HEAD is caught by the --contains set.
	local current_branch = out(sys({ "git", "symbolic-ref", "--short", "-q", "HEAD" }))
	local head_dist = count(trunk_fork .. "..HEAD")

	local contains_head = {}
	local children = sys({ "git", "branch", "--contains", "HEAD", "--format=%(refname:short)" })
	if children.code == 0 then
		for branch in vim.gsplit(children.stdout, "\n", { trimempty = true }) do
			contains_head[vim.trim(branch)] = true
		end
	end

	local region = sys({ "git", "branch", "--contains", trunk_fork, "--format=%(refname:short)" })
	local best_sha, best_branch, best_depth = nil, nil, 0
	if region.code == 0 then
		for raw in vim.gsplit(region.stdout, "\n", { trimempty = true }) do
			local branch = vim.trim(raw)
			if branch ~= "" and branch ~= current_branch and not contains_head[branch] then
				local branch_dist = count(trunk_fork .. ".." .. branch)
				if branch_dist > 0 and branch_dist < head_dist then
					local mb = out(sys({ "git", "merge-base", "HEAD", branch }))
					if mb and mb ~= "" and mb ~= trunk_fork then
						local depth = count(trunk_fork .. ".." .. mb)
						if depth > best_depth then
							best_sha, best_branch, best_depth = mb, branch, depth
						end
					end
				end
			end
		end
	end

	if best_sha then
		return best_sha, "fork point from stack parent " .. best_branch
	end
	return trunk_fork, "fork point from " .. trunk
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
