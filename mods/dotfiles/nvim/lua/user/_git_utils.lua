local plenary_ok, PlenaryJob = pcall(require, "plenary.job")
if not plenary_ok then
	vim.notify("plenary not found")
	return
end

local project_utils = require("user._project_utils")
local file_utils = require("user._file_utils")

local M = {}

function M.git_dir_path()
	local handle = io.popen("git rev-parse --show-toplevel 2> /dev/null")
	if handle ~= nil then
		local result = handle:read("*a")
		for line in result:gmatch("[^\r\n]+") do
			return line
		end
		handle:close()
	end
	-- Change the current dir in neovim.
	-- Run `git pull`, etc.
end

function M.get_prod_git_branch()
	return project_utils.get_project_config().branches.prod
end

function M.get_primary_git_branch(default_branch)
	if default_branch == nil then
		default_branch = project_utils.get_project_config().branches.main
	end
	local status_ok, handle =
		pcall(io.popen, "git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'")
	if not status_ok then
		return default_branch
	end
	if handle ~= nil then
		local result = handle:read("*a")
		if result == nil or result:match("fatal") or result == "" then
			return default_branch
		end
		return result:gsub("\n", "")
	end
	return default_branch
end

local function trim_git_modification_indicator(cmd_output)
	return cmd_output:match("[^%s]+$")
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
