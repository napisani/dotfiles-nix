local M = {}

function M.table_has_value(tab, val)
	for _, value in ipairs(tab) do
		if value == val then
			return true
		end
	end
	return false
end

function M.table_merge(t1, t2)
	local result = {}
	for k, v in pairs(t1) do
		result[k] = v
	end
	for k, v in pairs(t2) do
		result[k] = v
	end
	return result
end

-- combine multiple list-like tables into a single list table
function M.extend_lists(...)
	local result = {}
	for _, list in ipairs({ ... }) do
		vim.list_extend(result, list)
	end
	return result
end

M.merge_list = M.extend_lists

return M
