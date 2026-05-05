local vim = vim
local file_utils = require("user.utils.file_utils")
local collection_utils = require("user.utils.collection_utils")
local project_utils = require("user.utils.project_utils")
local git_utils = require("user.utils.git_utils")
local M = {}

local _combine_utils = function(util_modules)
	for _, module in ipairs(util_modules) do
		for k, v in pairs(module) do
			M[k] = v
		end
	end
end

_combine_utils({
	file_utils,
	collection_utils,
	project_utils,
	git_utils,
})

function M.python_path()
	if os.getenv("VIRTUAL_ENV") ~= nil then
		return os.getenv("VIRTUAL_ENV") .. "/bin/python"
	end
	local python_bin = "python"
	return python_bin
end

function M.debug_log(data, file_path)
	file_path = file_path or "/tmp/nvim.log"

	-- Convert data to string if it's not already
	local content
	if type(data) ~= "string" then
		content = vim.inspect(data)
	else
		content = data
	end

	-- Append to file
	local file = io.open(file_path, "a")
	if file then
		file:write(os.date("[%Y-%m-%d %H:%M:%S] "))
		file:write(content)
		file:write("\n\n")
		file:close()
	else
		vim.notify("Failed to write to log file", vim.log.levels.ERROR)
	end
end

return M
