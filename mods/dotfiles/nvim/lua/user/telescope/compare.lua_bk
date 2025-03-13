local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local utils = require("user.utils")
local os_sep = utils.path_sep
local find_files_from_root = require("user.telescope.find_files").find_files_from_root
local M = {}

function M.find_file_from_root_to_compare_to()
	M.find_file_from_root_and_callback(function(prompt_bufnr)
		actions.close(prompt_bufnr)
		local selected_entry = action_state.get_selected_entry()
		if selected_entry ~= nil and selected_entry[1] ~= nil then
			local root_dir = utils.get_root_dir()
			local file_name = vim.fn.resolve(root_dir .. os_sep .. selected_entry[1])
			vim.cmd("vertical diffsplit " .. file_name)
		end
	end)
end

function M.find_file_from_root_and_callback(callback_fn)
	find_files_from_root({
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				callback_fn(prompt_bufnr)
			end)
			return true
		end,
	})
end

return M
