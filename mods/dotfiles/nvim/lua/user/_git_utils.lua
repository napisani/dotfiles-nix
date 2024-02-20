local project_utils = require("user._project_utils")
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

return M
