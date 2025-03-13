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
