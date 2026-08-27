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

return M
