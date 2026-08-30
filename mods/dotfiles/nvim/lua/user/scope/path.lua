-- Directory or glob scope: at most one active scope.
-- Directory scopes narrow picker cwd; glob scopes filter paths relative to the
-- workspace root. Both are intentionally ephemeral and replace one another.
local M = {}
local state = require("user.scope.state")

local function normalize(path)
	return (path or ""):gsub("\\", "/"):gsub("^%./", ""):gsub("/+$", "")
end

local function root_relative(path, root)
	path = normalize(path)
	if path:sub(1, 1) ~= "/" then
		return path
	end

	root = normalize(root)
	if root ~= "" and path:sub(1, #root + 1) == root .. "/" then
		return path:sub(#root + 2)
	end
	return path
end

local function glob_to_lua_pattern(glob)
	local out = {}
	local i = 1
	while i <= #glob do
		local char = glob:sub(i, i)
		if char == "*" and glob:sub(i + 1, i + 1) == "*" then
			table.insert(out, ".*")
			i = i + 2
			if glob:sub(i, i) == "/" then
				i = i + 1
			end
		elseif char == "*" then
			table.insert(out, "[^/]*")
			i = i + 1
		elseif char == "?" then
			table.insert(out, ".")
			i = i + 1
		elseif char:match("[%(%)%.%%%+%-%[%]%^%$]") then
			table.insert(out, "%" .. char)
			i = i + 1
		else
			table.insert(out, char)
			i = i + 1
		end
	end
	return "^" .. table.concat(out) .. "$"
end

local function valid_glob(glob)
	if type(glob) ~= "string" then
		return false, "scope must be a string"
	end
	glob = normalize(glob)
	if glob == "" then
		return false, "scope cannot be empty"
	end
	if glob:sub(1, 1) == "/" then
		return false, "scope must be workspace-relative"
	end
	if glob == ".." or glob:match("^%.%./") or glob:match("/%.%./") or glob:match("/%.%.$") then
		return false, "scope cannot contain .."
	end
	if glob:find("%s") then
		return false, "scope cannot contain whitespace"
	end
	if glob:find("[{}]") then
		return false, "scope uses unsupported brace syntax"
	end
	return true, glob
end

function M.validate_globs(globs)
	if type(globs) == "string" then
		globs = { globs }
	end
	if type(globs) ~= "table" or #globs == 0 then
		return nil, "scope must contain at least one glob"
	end

	local normalized = {}
	for index, glob in ipairs(globs) do
		local ok, value_or_error = valid_glob(glob)
		if not ok then
			return nil, "scope " .. tostring(index) .. ": " .. value_or_error
		end
		table.insert(normalized, value_or_error)
	end
	return normalized
end

function M.clear_scopes()
	state.clear()
end

---@param scope string|string[]
---@param kind "directory"|"glob"
---@return boolean, string? error
function M.set_scope(scope, kind, name)
	if kind ~= "directory" and kind ~= "glob" then
		return false, "scope kind must be directory or glob"
	end

	local root = normalize(require("user.utils.file_utils").get_root_dir())
	if kind == "directory" then
		if type(scope) ~= "string" or normalize(scope) == "" then
			return false, "scope cannot be empty"
		end
		state.set({ value = normalize(scope), kind = kind, name = name, root = root })
		return true
	end

	local patterns, error_message = M.validate_globs(scope)
	if not patterns then
		return false, error_message
	end
	local compiled = {}
	for _, pattern in ipairs(patterns) do
		table.insert(compiled, glob_to_lua_pattern(pattern))
	end
	state.set({ kind = kind, patterns = patterns, compiled = compiled, name = name, root = root })
	return true
end

function M.add_scope(scope)
	return M.set_scope(scope, "directory")
end

function M.set_glob_scope(scope, name)
	return M.set_scope(scope, "glob", name)
end

---@return string|string[]|nil
function M.active_scope()
	local active_scope = state.get()
	if not active_scope then
		return nil
	end
	if active_scope.kind == "directory" then
		return active_scope.value
	end
	if active_scope.kind == "glob" then
		return vim.deepcopy(active_scope.patterns)
	end
	return active_scope.name
end

---@return string[]
---@return string?
function M.active_scope_name()
	local active_scope = state.get()
	return active_scope and active_scope.name
end

---@return string[]
function M.active_scope_patterns()
	local active_scope = state.get()
	if not active_scope then
		return {}
	end
	if active_scope.kind == "directory" then
		return { active_scope.value }
	end
	if active_scope.kind == "glob" then
		return vim.deepcopy(active_scope.patterns)
	end
	return {}
end

---@return "directory"|"glob"|"category"|nil
function M.active_scope_kind()
	local active_scope = state.get()
	return active_scope and active_scope.kind
end

--- Whether a root-relative or absolute path belongs to the active scope.
function M.is_visible(path)
	local active_scope = state.get()
	if not active_scope or active_scope.kind == "category" then
		return true
	end

	local target = root_relative(path, active_scope.root)
	if active_scope.kind == "directory" then
		local scope = root_relative(active_scope.value, active_scope.root)
		return target == scope or target:sub(1, #scope + 1) == scope .. "/"
	end

	for _, compiled in ipairs(active_scope.compiled) do
		if target:match(compiled) then
			return true
		end
	end
	return false
end

--- Whether a directory should remain visible in a tree rooted at the workspace.
--- A directory is visible when it is inside the scope or can contain a match.
function M.is_tree_visible(path)
	local active_scope = state.get()
	if not active_scope or active_scope.kind == "category" then
		return true
	end

	local normalized_path = normalize(path)
	local root = normalize(active_scope.root)
	if normalized_path == root then
		return true
	end

	local target = root_relative(normalized_path, root)
	if active_scope.kind == "directory" then
		local scope = root_relative(active_scope.value, root)
		return target == scope
			or target:sub(1, #scope + 1) == scope .. "/"
			or scope:sub(1, #target + 1) == target .. "/"
	end

	for _, pattern in ipairs(active_scope.patterns) do
		local literal_prefix = pattern:match("^[^*?]*") or ""
		literal_prefix = literal_prefix:gsub("/+$", "")
		if
			literal_prefix == ""
			or target == literal_prefix
			or target:sub(1, #literal_prefix + 1) == literal_prefix .. "/"
			or literal_prefix:sub(1, #target + 1) == target .. "/"
		then
			return true
		end
	end
	return false
end

--- Drops glob-scope items.
function M.transform(item, _)
	local active_scope = state.get()
	if not active_scope or active_scope.kind ~= "glob" then
		return
	end
	local path = item and (item.file or item.text)
	if path and not M.is_visible(path) then
		return false
	end
end

function M.filter_paths(paths)
	return vim.tbl_filter(M.is_visible, paths or {})
end

function M.apply_to_picker(opts)
	local active_scope = state.get()
	opts = opts or {}
	if active_scope and active_scope.kind == "directory" then
		opts.cwd = active_scope.value
	end
	return opts
end

return M
