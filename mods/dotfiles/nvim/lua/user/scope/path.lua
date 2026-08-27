-- Directory scope: at most one active directory cwd override.
-- Moved verbatim (renamed apply_scopes_to_rg_picker -> apply_to_picker) from
-- the former lua/user/snacks/scope.lua.
local M = {}
local active_scopes = {}

M.clear_scopes = function()
	active_scopes = {}
end

M.add_scope = function(scope)
	M.clear_scopes()
	table.insert(active_scopes, scope)
end

M.apply_to_picker = function(opts)
	opts = opts or {}
	if #active_scopes > 0 then
		for _, scope in ipairs(active_scopes) do
			opts.cwd = scope
			break
		end
	end
	return opts
end

return M
