local M = {}

M.path_sep = "/"

function M.file_exists(name)
	local f = io.open(name, "r")
	return f ~= nil and io.close(f)
end

function M.read_json_file(filename)
	local contents = M.read_file_to_string(filename)
	if contents == nil then
		return nil
	end
	local json = vim.fn.json_decode(contents)
	return json
end

function M.read_yaml_file(filename)
	if not M.file_exists(filename) then
		return nil
	end
	local handle = io.popen(string.format("yq . %s --output-format json", filename))
	if handle == nil then
		return nil
	end
	local output = handle:read("*a")
	if output == nil or output == "" then
		return nil
	end
	handle:close()
	return vim.fn.json_decode(output)
end

function M.read_file_to_string(filename)
	if not M.file_exists(filename) then
		return nil
	end
	local path = io.open(filename, "r")
	if path ~= nil then
		return path:read("*a")
	end
	return nil
end

function M.join_path(...)
	local parts = { ... }
	return table.concat(parts, M.path_sep)
end

local _orig_root_dir = vim.fn.getcwd()
function M.get_root_dir()
	local root_dir = _orig_root_dir
	local git_dir = require("lspconfig.util").root_pattern(".git")(root_dir)
	if git_dir ~= nil and git_dir ~= "" then
		return git_dir
	end
	return root_dir
end

function M.read_package_json()
	return M.read_json_file("package.json")
end

-- Convert an absolute file path to a path relative to the root directory
-- @param file_path string: Absolute path to the file
-- @param root_dir string|nil: Root directory (defaults to get_root_dir())
-- @return string: Relative path from root, or original path if not under root
function M.get_relative_to_root(file_path, root_dir)
	root_dir = root_dir or M.get_root_dir()
	
	-- Ensure root_dir doesn't have trailing slash
	if root_dir:sub(-1) == M.path_sep then
		root_dir = root_dir:sub(1, -2)
	end
	
	-- Check if file_path starts with root_dir
	if file_path:sub(1, #root_dir) == root_dir then
		-- File is under root_dir, make it relative
		-- +2 to skip the root_dir and the path separator
		return file_path:sub(#root_dir + 2)
	end
	
	-- File is outside root_dir, return as-is
	return file_path
end

return M
