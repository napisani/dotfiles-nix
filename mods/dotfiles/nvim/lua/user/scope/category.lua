-- File category scope: classifies paths into a category (tests, documentation,
-- implementation catch-all) and lets categories be enabled/disabled at runtime.
-- Every disabled category is hidden across pickers, LSP lists, and Diffview.
local M = {}

M.NOTHING_MATCHES_SENTINEL = "zzz___scope_category_match_nothing___zzz"

-- order matters: checked top-to-bottom, first match wins; the entry with
-- `catchall = true` is used when nothing else matches and MUST be exactly one
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
		enabled = true,
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
		enabled = true,
	},
	implementation = {
		catchall = true,
		enabled = true,
	},
}

local catchall_name
for name, def in pairs(M.categories) do
	if def.catchall then
		assert(not catchall_name, "user.scope.category: only one category may be catchall")
		catchall_name = name
	end
end
assert(catchall_name, "user.scope.category: exactly one category must be marked catchall")

-- Compiles a small glob subset (`*`, `**`, `?`, literals) to an anchored Lua
-- pattern. `**` matches across path segments (including the empty string);
-- `*` matches within a single segment.
local function glob_to_lua_pattern(glob)
	local out = {}
	local i, n = 1, #glob
	while i <= n do
		local c = glob:sub(i, i)
		if c == "*" and glob:sub(i + 1, i + 1) == "*" then
			table.insert(out, ".*")
			i = i + 2
			if glob:sub(i, i) == "/" then
				i = i + 1
			end
		elseif c == "*" then
			table.insert(out, "[^/]*")
			i = i + 1
		elseif c == "?" then
			table.insert(out, ".")
			i = i + 1
		elseif c:match("[%(%)%.%%%+%-%[%]%^%$]") then
			table.insert(out, "%" .. c)
			i = i + 1
		else
			table.insert(out, c)
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

---@return string[]
function M.list_names()
	return vim.deepcopy(M.order)
end

---@param name string
---@return boolean
function M.is_enabled(name)
	local def = M.categories[name]
	return def ~= nil and def.enabled == true
end

---@param name string
---@param enabled boolean
function M.set_enabled(name, enabled)
	local def = M.categories[name]
	if def then
		def.enabled = enabled
	end
end

--- Resets every category's enabled flag to true.
function M.reset_all()
	for _, def in pairs(M.categories) do
		def.enabled = true
	end
end

local function normalize_path(path)
	return (path or ""):gsub("\\", "/")
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
	return M.is_enabled(M.classify(path))
end

---@param paths string[]
---@return string[]
function M.filter_paths(paths)
	return vim.tbl_filter(function(p)
		return M.is_visible(p)
	end, paths or {})
end

---@type snacks.picker.transform
--- Drops (returns false for) any item whose item.file is not visible.
function M.transform(item, _)
	local path = item and (item.file or item.text)
	if not path then
		return
	end
	if not M.is_visible(path) then
		return false
	end
end

---@return string[]
function M.diffview_pathspec_args()
	local any_disabled = false
	for _, name in ipairs(M.order) do
		if not M.categories[name].enabled then
			any_disabled = true
			break
		end
	end
	if not any_disabled then
		return {}
	end

	local catchall_def = M.categories[catchall_name]
	if catchall_def.enabled then
		-- exclude mode: negative patterns for every disabled non-catch-all category
		local args = {}
		for _, name in ipairs(M.order) do
			local def = M.categories[name]
			if not def.catchall and not def.enabled then
				for _, pattern in ipairs(def.patterns) do
					table.insert(args, ":!" .. pattern)
				end
			end
		end
		return args
	end

	-- catch-all disabled: include mode, union of enabled non-catch-all categories
	local args = {}
	for _, name in ipairs(M.order) do
		local def = M.categories[name]
		if not def.catchall and def.enabled then
			for _, pattern in ipairs(def.patterns) do
				table.insert(args, pattern)
			end
		end
	end

	if #args == 0 then
		-- everything disabled: an empty positive pathspec means "no restriction"
		-- to git, which is the opposite of intent, so match nothing instead.
		return { M.NOTHING_MATCHES_SENTINEL }
	end

	return args
end

return M
