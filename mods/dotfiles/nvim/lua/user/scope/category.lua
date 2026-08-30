-- Built-in file-category scopes. Categories classify paths into exactly one
-- category; selecting one category makes it the active mutually-exclusive scope.
local M = {}
local state = require("user.scope.state")

M.NOTHING_MATCHES_SENTINEL = "zzz___scope_category_match_nothing___zzz"
M.PATHSPEC_INCLUDE = ":(glob)"
M.PATHSPEC_EXCLUDE = ":(glob,exclude)"

M.order = { "tests", "documentation", "implementation" }
M.categories = {
	tests = {
		patterns = {
			"**/*_test.*",
			"**/*.test.*",
			"**/*_spec.*",
			"**/*.spec.*",
			"**/test/**",
			"**/tests/**",
			"**/__tests__/**",
		},
	},
	documentation = {
		patterns = {
			"**/*.md",
			"**/*.mdx",
			"**/*.adoc",
			"**/docs/**",
			"**/doc/**",
			"**/README*",
			"**/CHANGELOG*",
		},
	},
	implementation = {
		catchall = true,
	},
}

local catchall_name
for name, def in pairs(M.categories) do
	if def.catchall then
		assert(not catchall_name, "user.scope.category: only one category may be catchall")
		catchall_name = name
	end
end
assert(catchall_name, "user.scope.category: exactly one category must be catchall")

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

for _, def in pairs(M.categories) do
	if def.patterns then
		def.compiled = {}
		for _, glob in ipairs(def.patterns) do
			table.insert(def.compiled, glob_to_lua_pattern(glob))
		end
	end
end

local function normalize_path(path)
	return (path or ""):gsub("\\", "/")
end

---@return string[]
function M.list_names()
	return vim.deepcopy(M.order)
end

---@param name string
---@return string[]?
function M.patterns_for(name)
	local def = M.categories[name]
	return def and def.patterns and vim.deepcopy(def.patterns)
end

---@return string?
function M.active_scope_name()
	local active = state.get()
	return active and active.kind == "category" and active.name or nil
end

---@param name string
---@return boolean, string?
function M.select_scope(name)
	if not M.categories[name] then
		return false, "unknown built-in scope: " .. tostring(name)
	end
	state.set({ kind = "category", name = name })
	return true
end

---@param path string
---@return string
function M.classify(path)
	local normalized = normalize_path(path)
	for _, name in ipairs(M.order) do
		local def = M.categories[name]
		if not def.catchall then
			for _, lua_pattern in ipairs(def.compiled) do
				if normalized:match(lua_pattern) then
					return name
				end
			end
		end
	end
	return catchall_name
end

---@param path string
---@return boolean
function M.is_visible(path)
	local active_name = M.active_scope_name()
	return active_name == nil or M.classify(path) == active_name
end

---@param paths string[]
---@return string[]
function M.filter_paths(paths)
	return vim.tbl_filter(M.is_visible, paths or {})
end

---@type snacks.picker.transform
function M.transform(item, _)
	local path = item and (item.file or item.text)
	if path and not M.is_visible(path) then
		return false
	end
end

local function tree_prefix(pattern)
	return (pattern:match("^[^*?]*") or ""):gsub("/+$", "")
end

---@param path string
---@return boolean
function M.is_tree_visible(path)
	local active_name = M.active_scope_name()
	if not active_name or active_name == catchall_name then
		return true
	end
	local normalized = normalize_path(path)
	for _, pattern in ipairs(M.categories[active_name].patterns) do
		local prefix = tree_prefix(pattern)
		if
			prefix == ""
			or normalized == prefix
			or normalized:sub(1, #prefix + 1) == prefix .. "/"
			or prefix:sub(1, #normalized + 1) == normalized .. "/"
		then
			return true
		end
	end
	return false
end

---@return string[]
function M.diffview_pathspec_args()
	local active_name = M.active_scope_name()
	if not active_name then
		return {}
	end
	if active_name == catchall_name then
		local args = { M.PATHSPEC_INCLUDE .. "**" }
		for _, name in ipairs(M.order) do
			local def = M.categories[name]
			if not def.catchall then
				for _, pattern in ipairs(def.patterns) do
					table.insert(args, M.PATHSPEC_EXCLUDE .. pattern)
				end
			end
		end
		return args
	end
	local args = {}
	for _, pattern in ipairs(M.categories[active_name].patterns) do
		table.insert(args, M.PATHSPEC_INCLUDE .. pattern)
	end
	return args
end

-- Compatibility name for callers that used the old reset operation. It now
-- clears the single shared active scope rather than re-enabling categories.
function M.reset_all()
	state.clear()
end

return M
