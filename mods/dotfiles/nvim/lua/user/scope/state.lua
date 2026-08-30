local M = {}
local active_scope

function M.get()
	return active_scope and vim.deepcopy(active_scope)
end

function M.set(scope)
	active_scope = vim.deepcopy(scope)
end

function M.clear()
	active_scope = nil
end

return M
