-- Composition entrypoint used by all Snacks-picker consumers: composes
-- directory scope (path.lua) with category scope (category.lua) so no
-- consumer needs to know about them separately.
local M = {}

--- Composes path-scope's cwd override with category-scope's per-item filter.
---@param opts table  -- snacks.picker.Config-shaped opts being built
---@return table       -- opts, mutated in place and returned
function M.apply_to_picker(opts)
	opts = require("user.scope.path").apply_to_picker(opts)
	local category = require("user.scope.category")
	local existing_transform = opts.transform
	opts.transform = function(item, ctx)
		if category.transform(item, ctx) == false then
			return false
		end
		if existing_transform then
			return existing_transform(item, ctx)
		end
	end
	return opts
end

--- For consumers that build picker items from an already-materialized path
--- list (git changed-files style pickers) rather than a Snacks finder.
---@param paths string[]
---@return string[]
function M.filter_paths(paths)
	return require("user.scope.category").filter_paths(paths)
end

local function normalize(p)
	-- extra parens: gsub also returns a match count, which would leak into
	-- table constructors and multi-value returns at the call sites.
	return ((p or ""):gsub("\\", "/"):gsub("/+$", ""))
end

---@param dir string
---@param target string
---@return boolean
local function is_under(dir, target)
	dir, target = normalize(dir), normalize(target)
	return target == dir or target:sub(1, #dir + 1) == dir .. "/"
end

--- Confines a positive category pathspec to the active directory scope,
--- keeping its `:(glob)` magic prefix at the front where git expects it.
---@param dir string
---@param pathspec string
---@return string
local function scope_positive(dir, pathspec)
	local category = require("user.scope.category")
	local pattern = pathspec:sub(1 + #category.PATHSPEC_INCLUDE)
	return category.PATHSPEC_INCLUDE .. normalize(dir) .. "/" .. pattern
end

--- Diffview's only seam is git pathspec args, so both scopes have to be
--- expressed there rather than filtered per item. Git ORs positive
--- pathspecs, which means directory scope cannot simply be appended
--- alongside category patterns -- it has to be folded into each one.
---@param target? string  -- optional single-file target, relative to cwd
---@return string[]|nil    -- nil means nothing is visible under the active scopes
function M.diffview_pathspec_args(target)
	local category = require("user.scope.category")
	local dir = require("user.scope.path").active_scope()

	if target and target ~= "" then
		-- A single file is narrower than any scope: it either survives both
		-- scopes intact or there is nothing left to show.
		if not category.is_visible(target) then
			return nil
		end
		if dir and not is_under(dir, target) then
			return nil
		end
		return { target }
	end

	local args = category.diffview_pathspec_args()
	if not dir then
		return args
	end

	local dir_all = category.PATHSPEC_INCLUDE .. normalize(dir) .. "/**"
	if #args == 0 then
		return { dir_all }
	end

	local out, has_positive = {}, false
	for _, arg in ipairs(args) do
		if arg:sub(1, #category.PATHSPEC_EXCLUDE) == category.PATHSPEC_EXCLUDE then
			table.insert(out, arg)
		else
			has_positive = true
			table.insert(out, scope_positive(dir, arg))
		end
	end
	if not has_positive then
		-- exclude mode contributes negatives only; the scope dir is what
		-- narrows the search in the first place.
		table.insert(out, dir_all)
	end
	return out
end

return M
