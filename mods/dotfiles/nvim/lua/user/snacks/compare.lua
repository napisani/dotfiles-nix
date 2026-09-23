local Snacks = require("snacks")
local utils = require("user.utils")
local os_sep = utils.path_sep
local find_files_from_root = require("user.snacks.find_files").find_files_from_root
local M = {}

function M.find_file_from_root_to_compare_to()
	M.find_file_from_root_and_callback(function(item)
		if item and item.file then
			local root_dir = utils.get_root_dir()
			local file_name = vim.fn.resolve(root_dir .. os_sep .. item.file)
			vim.cmd("vertical diffsplit " .. file_name)
		end
	end)
end

function M.find_file_from_root_and_callback(callback_fn)
	find_files_from_root({
		confirm = function(picker, item)
			picker:close()
			if item then
				callback_fn(item)
			end
		end,
	})
end

local function apply_pull_request_base(result)
	utils.set_git_ref(result.commit)
	local message = string.format(
		"git ref set to PR merge base %s (parent: %s, source: %s)",
		result.commit:sub(1, 12),
		result.parent,
		result.source
	)
	vim.notify(message, vim.log.levels.INFO)
end

local function select_pull_request_parent(pr_base)
	Snacks.picker.git_branches({
		all = false,
		confirm = function(picker, item)
			picker:close()
			if not item or not item.branch then
				return
			end
			local result, err = pr_base.remember_and_resolve(item.branch)
			if not result then
				vim.notify(err.message, vim.log.levels.WARN)
				return
			end
			apply_pull_request_base(result)
		end,
	})
end

function M.set_git_ref_to_pull_request_base()
	local pr_base = require("user.utils.git_pr_base")
	local result, err = pr_base.resolve()
	if result then
		apply_pull_request_base(result)
		return
	end
	if err.kind == "parent_required" then
		vim.notify(err.message .. "; select one to remember", vim.log.levels.INFO)
		select_pull_request_parent(pr_base)
		return
	end
	vim.notify(err.message, vim.log.levels.WARN)
end

function M.establish_git_ref(commit)
	if commit then
		Snacks.picker.git_log({
			all = true,
			confirm = function(picker, item)
				picker:close()
				if item and item.commit then
					utils.set_git_ref(item.commit)
				end
			end,
		})
	else
		Snacks.picker.git_branches({
			all = true,
			confirm = function(picker, item)
				picker:close()
				if item and item.branch then
					utils.set_git_ref(item.branch)
				end
			end,
		})
	end
end

return M
