local M = {}

M.path_sep = "/"

function M.home_directory()
	return os.getenv("HOME")
end

function M.temp_directory()
	return os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
end

function M.create_temp_directory(prefix)
	local temp_dir = M.temp_directory()
	local temp_name = os.tmpname()
	local temp_path = temp_dir .. "/" .. prefix .. temp_name
	vim.fn.mkdir(temp_path, "p")
	return temp_path
end

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

function M.file_string_to_lines(str)
	local lines = {}
	for s in str:gmatch("[^\r\n]+") do
		table.insert(lines, s)
	end
	return lines
end

function M.file_safe_name(name)
	return name:gsub("[^%w_-]", "_")
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

function M.write_string_to_file(filename, content)
	local fd = io.open(filename, "w")
	fd:write(content)
	fd:close()
end

return M
