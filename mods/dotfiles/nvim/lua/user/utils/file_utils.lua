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
	local json = vim.json.decode(contents)
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
	return vim.json.decode(output)
end

function M.read_file_to_string(filename)
	if not M.file_exists(filename) then
		return nil
	end
	local fh = io.open(filename, "r")
	if fh ~= nil then
		local content = fh:read("*a")
		fh:close()
		return content
	end
	return nil
end

function M.join_path(...)
	local parts = { ... }
	return table.concat(parts, M.path_sep)
end

function M.get_root_dir()
	-- Use git to find the root at call time, not at load time.
	-- This correctly handles worktrees (where .git is a file, not a dir)
	-- and sessions started from a subdirectory.
	local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")
	if git_root and #git_root > 0 and git_root[1] ~= "" and not git_root[1]:match("^fatal") then
		return git_root[1]
	end
	-- Fallback: current working directory
	return vim.fn.getcwd()
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
