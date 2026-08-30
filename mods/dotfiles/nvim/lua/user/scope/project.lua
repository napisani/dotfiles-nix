local path = require("user.scope.path")
local project_utils = require("user.utils.project_utils")

local M = {}

M.RESERVED_NAMES = {
	tests = true,
	documentation = true,
	implementation = true,
}

local function valid_name(name)
	return type(name) == "string" and name:match("^[%a][%w_-]*$") ~= nil and not M.RESERVED_NAMES[name]
end

---@return { name: string, patterns: string[] }[], string[]
function M.list_scopes()
	local configured = project_utils.get_project_config().scopes
	if configured == nil then
		return {}, {}
	end
	if type(configured) ~= "table" then
		return {}, { "project_config.scopes must be a table" }
	end

	local scopes, errors = {}, {}
	for name, globs in pairs(configured) do
		if not valid_name(name) then
			table.insert(errors, "invalid or reserved project scope name: " .. tostring(name))
		else
			local patterns, err = path.validate_globs(globs)
			if patterns then
				table.insert(scopes, { name = name, patterns = patterns })
			else
				table.insert(errors, name .. ": " .. err)
			end
		end
	end
	table.sort(scopes, function(left, right)
		return left.name < right.name
	end)
	return scopes, errors
end

---@param name string
---@return { name: string, patterns: string[] }?
function M.find_scope(name)
	for _, scope in ipairs(M.list_scopes()) do
		if scope.name == name then
			return scope
		end
	end
end

---@param name string
---@return boolean, string?
function M.select_scope(name)
	if M.RESERVED_NAMES[name] then
		return require("user.scope.category").select_scope(name)
	end
	local scope = M.find_scope(name)
	if not scope then
		return false, "unknown project scope: " .. tostring(name)
	end
	return path.set_glob_scope(scope.patterns, scope.name)
end

return M
