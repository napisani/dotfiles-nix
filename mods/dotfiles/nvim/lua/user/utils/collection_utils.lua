local M = {}

function M.table_has_value(tab, val)
	for _, value in ipairs(tab) do
		if value == val then
			return true
		end
	end
	return false
end

-- combine multiple list-like tables into a single list table
function M.extend_lists(...)
	local result = {}
	for _, list in ipairs({ ... }) do
		vim.list_extend(result, list)
	end
	return result
end

return M
