local vim = vim
local M = {}

function M.merge_list(t1, t2)
	local new_list = {}
	for _, v in ipairs(t1) do
		table.insert(new_list, v)
	end
	for _, v in ipairs(t2) do
		table.insert(new_list, v)
	end
	return new_list
end

function M.table_has_value(tab, val)
	for _, value in ipairs(tab) do
		if value == val then
			return true
		end
	end
	return false
end

function M.table_merge(t1, t2)
	local result = {}
	for k, v in pairs(t1) do
		result[k] = v
	end
	for k, v in pairs(t2) do
		result[k] = v
	end
	return result
end

function M.deep_copy(object)
	if type(object) ~= "table" then
		return object
	end

	local result = {}
	for key, value in pairs(object) do
		result[key] = M.deep_copy(value)
	end
	return result
end

function M.spread(template)
	return function(table)
		local result = {}
		for key, value in pairs(template) do
			result[key] = M.deep_copy(value) -- Note the deep copy!
		end

		for key, value in pairs(table) do
			result[key] = value
		end
		return result
	end
end

function M.home_directory()
	return os.getenv("HOME")
end

function M.temp_directory()
	return os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
end

function M.file_exists(name)
	local f = io.open(name, "r")
	return f ~= nil and io.close(f)
end

function M.read_json_file(filename)
	if not M.file_exists(filename) then
		return nil
	end
	local path = io.open(filename, "r")
	if path ~= nil then
		local json_contents = path:read("*a")
		local json = vim.fn.json_decode(json_contents)
		return json
	end

	return nil
end

function M.read_package_json()
	return M.read_json_file("package.json")
end

function M.is_npm_package_installed(package)
	local package_json = M.read_package_json()
	if not package_json then
		return false
	end

	if package_json.dependencies and package_json.dependencies[package] then
		return true
	end

	if package_json.devDependencies and package_json.devDependencies[package] then
		return true
	end

	return false
end

-- Useful function for debugging
-- Print the given items
function M.print(...)
	local objects = vim.tbl_map(vim.inspect, { ... })
	print(unpack(objects))
	-- local file_descriptor = io.open("/tmp/tta", "w")
	-- file_descriptor:write(unpack(objects))
end

-- compare current buffer to clipboard
-- :call v:lua.compare_to_clipboard()<CR>
function _G.compare_to_clipboard()
	local ftype = vim.api.nvim_eval("&filetype")
	vim.cmd("vsplit")
	vim.cmd("enew")
	vim.cmd("normal! P")
	vim.cmd("setlocal buftype=nowrite")
	vim.cmd("set filetype=" .. ftype)
	vim.cmd("diffthis")
	vim.cmd([[execute "normal! \<C-w>h"]])
	vim.cmd("diffthis")
end

function _G.compare_to_clipboard_other()
	local ftype = vim.api.nvim_eval("&filetype")
	vim.cmd(string.format(
		[[
    execute "normal! \"xy"
    vsplit
    enew
    normal! P
    setlocal buftype=nowrite
    set filetype=%s
    diffthis
    execute "normal! \<C-w>\<C-w>"
    enew
    set filetype=%s
    normal! "xP
    diffthis
  ]],
		ftype,
		ftype
	))
end

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

-- function M.reload_nvim_conf()
--   for name,_ in pairs(package.loaded) do
--     if name:match('^dap') or name:match('^user.nvim-dap') or name:match('.*nvim-dap.*') then
--       print("Reloading", name)

--       package.loaded[name] = nil
--     end
--   end

--   dofile('/Users/nick/.config/nvim/lua/user/init.lua')
--   vim.notify("Nvim configuration reloaded!", vim.log.levels.INFO)
-- end

function M.global_node_modules()
	local handle = io.popen("npm root -g")
	local node_modules_dir = nil
	if handle ~= nil then
		local result = handle:read("*a")
		for line in result:gmatch("[^\r\n]+") do
			node_modules_dir = line
		end
	end
	-- print("python_bin", python_bin)
	return node_modules_dir
end

function M.python_path()
	if os.getenv("VIRTUAL_ENV") ~= nil then
		return os.getenv("VIRTUAL_ENV") .. "/bin/python"
	end
	-- local handle = io.popen("pyenv which python")
	local python_bin = "python"
	-- if handle ~= nil then
	-- 	local result = handle:read("*a")
	-- 	for line in result:gmatch("[^\r\n]+") do
	-- 		python_bin = line
	-- 	end
	-- end
	-- print("python_bin", python_bin)
	return python_bin
end

function M.get_db_connections()
	local sql_rc = M.get_root_dir() .. "/.sqllsrc.json"
	local json_file = M.read_json_file(sql_rc)
	if json_file == nil then
		return {}
	end
	local conns = {}
	if json_file["connections"] ~= nil then
		conns = json_file["connections"]
	end
	if json_file["host"] ~= nil then
		table.insert(conns, json_file)
	end
	return conns
end

function M.connection_to_golang_string(conn)
	-- if conn['adapter'] ~= "mysql" then
	--   vim.notify("Only mysql is supported", vim.log.levels.ERROR)
	--   return nil
	-- end
	local user = conn["user"]
	local password = conn["password"]
	local database = conn["database"]
	local host = conn["host"]
	local port = conn["port"] or 3306
	local conn_string = user .. ":" .. password .. "@tcp(" .. host .. ":" .. port .. ")/" .. database
	return conn_string
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

local default_config = {
	lint = {},
	branches = {
		main = "main",
		prod = "production",
	},
	debug = {
		launch_file = ".vscode/launch.json",
	},
}

local project_config = nil
function M.get_project_config()
	if project_config ~= nil then
		return project_config
	end
	local nvim_rc = M.get_root_dir() .. "/.nvimrc.json"
	local json_file = M.read_json_file(nvim_rc)
	if json_file == nil then
		project_config = default_config
		return project_config
	end
	local settings = {}
	for k, v in pairs(default_config) do
		settings[k] = v
		if json_file[k] ~= nil then
			settings[k] = json_file[k]
		end
	end
	project_config = settings
	return settings
end

function M.reset_project_config_cache()
	project_config = nil
end

function M.get_prod_git_branch()
	return M.get_project_config().branches.prod
end

function M.get_debugger_launch_file()
	return M.get_project_config().debug.launch_file
end

function M.get_primary_git_branch(default_branch)
	if default_branch == nil then
		default_branch = M.get_project_config().branches.main
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
