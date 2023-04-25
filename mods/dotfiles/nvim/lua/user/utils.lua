local M = {}
function M.table_merge(t1, t2)
	for _, v in ipairs(t2) do
		table.insert(t1, v)
	end

	return t1
end
function M.home_directory()
  return os.getenv('HOME')
end
function M.temp_directory()
  return os.getenv('TMPDIR') or os.getenv("TEMP")  or os.getenv("TMP") or '/tmp'
end

function M.read_json_file(filename)
	local path = Path:new(filename)
	if not path:exists() then
		return nil
	end

	local json_contents = path:read()
	local json = vim.fn.json_decode(json_contents)

	return json
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
    local handle = io.popen('git rev-parse --show-toplevel 2> /dev/null')
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
-- vim.keymap.set("x", "<Space>d", compare_to_clipboard)
return M
