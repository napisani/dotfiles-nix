local M = {}
local active_scopes = {}

-- this works but it overrides all of the rules in git ignore
-- for now we will use one scope at a time not multiple
-- M.get_rg_args = function()
-- 	local args = {}
-- 	for _, scope in ipairs(active_scopes) do
-- 		table.insert(args, "--glob=" .. scope .. "**")
-- 	end
-- 	return args
-- end

M.clear_scopes = function()
	active_scopes = {}
end

M.add_scope = function(scope)
	-- if not vim.tbl_contains(active_scopes, scope) then
	-- 	table.insert(active_scopes, scope)
	-- end
	M.clear_scopes()
	table.insert(active_scopes, scope)
end

M.apply_scopes_to_rg_picker = function(opts)
	opts = opts or {}
	-- local args = M.get_rg_args()
	-- if #args > 0 then
	-- 	opts.args = vim.tbl_extend("force", opts.args or {}, args)
	-- end
	if #active_scopes > 0 then
		for _, scope in ipairs(active_scopes) do
			opts.cwd = scope
			break
		end
	end
	return opts
end

return M
