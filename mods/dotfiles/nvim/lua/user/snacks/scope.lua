local M = {}
local active_scopes = {}
M.get_rg_args = function()
	local args = {}
	for _, scope in ipairs(active_scopes) do
		table.insert(args, "--glob=" .. scope .. "**")
	end
	return args
end

M.add_scope = function(scope)
	if not vim.tbl_contains(active_scopes, scope) then
		table.insert(active_scopes, scope)
	end
end

M.clear_scopes = function()
	active_scopes = {}
end

M.apply_scopes_to_rg_picker = function(opts)
	opts = opts or {}
	local args = M.get_rg_args()
	if #args > 0 then
		opts.args = vim.tbl_extend("force", opts.args or {}, args)
	end
	return opts
end

return M
