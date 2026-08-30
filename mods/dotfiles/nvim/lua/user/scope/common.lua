-- Composition entrypoint used by all Snacks-picker consumers: composes
-- directory/glob scope (path.lua) with category scope (category.lua) so no
-- consumer needs to know about them separately.
local M = {}

--- Whether a file passes both the path and category scopes.
---@param path string
---@return boolean
function M.is_visible(path)
	return require("user.scope.path").is_visible(path) and require("user.scope.category").is_visible(path)
end

--- Composes path-scope's cwd/transform with category-scope's per-item filter.
---@param opts table  -- snacks.picker.Config-shaped opts being built
---@return table       -- opts, mutated in place and returned
function M.apply_to_picker(opts)
	opts = require("user.scope.path").apply_to_picker(opts)
	local path = require("user.scope.path")
	local category = require("user.scope.category")
	local existing_transform = opts.transform
	opts.transform = function(item, ctx)
		if path.transform(item, ctx) == false then
			return false
		end
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
	local path = require("user.scope.path")
	local category = require("user.scope.category")
	return category.filter_paths(path.filter_paths(paths))
end

local function normalize(p)
	return ((p or ""):gsub("\\", "/"):gsub("/+$", ""))
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

local function workspace_paths()
	local root = require("user.utils.file_utils").get_root_dir()
	local result = vim.system({ "git", "ls-files", "--cached", "--others", "--exclude-standard" }, {
		cwd = root,
		text = true,
	}):wait()
	if result.code ~= 0 then
		vim.notify(
			"Could not enumerate scoped files: " .. (result.stderr or "git ls-files failed"),
			vim.log.levels.ERROR
		)
		return {}
	end
	return vim.split(result.stdout or "", "\n", { plain = true, trimempty = true })
end

local function has_positive_pathspec(args, category)
	for _, arg in ipairs(args) do
		if arg:sub(1, #category.PATHSPEC_EXCLUDE) ~= category.PATHSPEC_EXCLUDE then
			return true
		end
	end
	return false
end

--- Diffview's only seam is git pathspec args, so both scopes have to be
--- expressed there rather than filtered per item. Directory scopes can fold
--- into category positives. A glob scope crossed with positive category
--- pathspecs is materialized because Git ORs separate positive pathspecs.
---@param target? string  -- optional single-file target, relative to cwd
---@param candidate_paths? string[] -- injectable workspace file list for tests
---@return string[]|nil    -- nil means nothing is visible under the active scopes
function M.diffview_pathspec_args(target, candidate_paths)
	local category = require("user.scope.category")
	local path = require("user.scope.path")
	local scope = path.active_scope()
	local scope_kind = path.active_scope_kind()

	if target and target ~= "" then
		if not category.is_visible(target) or not path.is_visible(target) then
			return nil
		end
		return { target }
	end

	local args = category.diffview_pathspec_args()
	if not scope then
		return args
	end

	if scope_kind == "glob" then
		local out = {}
		for _, pattern in ipairs(path.active_scope_patterns()) do
			table.insert(out, category.PATHSPEC_INCLUDE .. normalize(pattern))
		end
		if #args == 0 then
			return out
		end
		if has_positive_pathspec(args, category) then
			local visible = M.filter_paths(candidate_paths or workspace_paths())
			if #visible == 0 then
				return { category.PATHSPEC_INCLUDE .. category.NOTHING_MATCHES_SENTINEL }
			end
			return visible
		end
		-- Exclude-mode negatives compose with the glob positives.
		for _, arg in ipairs(args) do
			table.insert(out, arg)
		end
		return out
	end

	local dir_all = category.PATHSPEC_INCLUDE .. normalize(scope) .. "/**"
	if #args == 0 then
		return { dir_all }
	end

	local out, has_positive = {}, false
	for _, arg in ipairs(args) do
		if arg:sub(1, #category.PATHSPEC_EXCLUDE) == category.PATHSPEC_EXCLUDE then
			table.insert(out, arg)
		else
			has_positive = true
			table.insert(out, scope_positive(scope, arg))
		end
	end
	if not has_positive then
		table.insert(out, dir_all)
	end
	return out
end

return M
