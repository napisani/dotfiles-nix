local status_ok, neoscopes = pcall(require, "neoscopes")
if not status_ok then
	vim.notify("neoscopes not found ")
	return
end

local utils = require("user.utils")
-- built_scopes = require("libmonoscope").scopes
-- for _, scope in ipairs(built_scopes) do
--   scopes.add(scope)
-- end
local ORIGINAL_PATH = vim.fn.getenv("PATH")
local set_venv = function(venv)
	local venv_bin_path = venv.path .. "/bin"
	vim.fn.setenv("PATH", venv_bin_path .. ":" .. ORIGINAL_PATH)
	vim.fn.setenv("VIRTUAL_ENV", venv.path)
end

neoscopes.setup({
	on_scope_selected = function(scope)
    vim.cmd("cd " .. utils.get_root_dir())
		if scope.name:find("^python:") ~= nil then
			vim.cmd("cd " .. scope.name:gsub('^python:', ''))
		end
	end,
})
M = {}
-- local utils = require("user.utils")
-- Let's say you are working on the networking area in the project.
neoscopes.add({
	name = "ROOT",
	dirs = {},
})

M.neoscopes = neoscopes
return M
-- scopes.add({
-- 	name = "web",
-- 	dirs = {
-- 		-- Relative directories in the repo.
-- 		"web",
-- 		"api",
-- 	},
-- })
-- And sometimes you also like doing some UI changes.
-- scopes.add({
-- 	name = "mobile",
-- 	dirs = {
-- 		-- Relative directories in the repo.
-- 		"mobile",
-- 	},
-- })
-- local cmp_main_scope = {
-- 	name = "main <-> this",
-- 	dirs = {},
-- }
-- local function populate_with_files_in_diff(rule, to, from)
-- 	rule.dirs = {}
-- 	local handle = io.popen("git diff --name-only --relative " .. to .. ".." .. from)
-- 	if handle ~= nil then
-- 		local result = handle:read("*a")
-- 		for line in result:gmatch("[^\r\n]+") do
-- 			table.insert(rule.dirs, "file:///" .. line)
-- 		end
-- 		handle:close()
-- 	end
-- end

-- cmp_main_scope["on_select"] = function()
-- 	populate_with_files_in_diff(cmp_main_scope, "main", "")
-- end

-- scopes.add(cmp_main_scope)

-- local cmp_origin_main_scope = {
-- 	name = "origin/main <-> this",
-- 	dirs = {},
-- }

-- cmp_origin_main_scope["on_select"] = function()
-- 	populate_with_files_in_diff(cmp_origin_main_scope, "origin/main", "")
-- end

-- scopes.add(cmp_origin_main_scope)
