local M = {}
function M.merge_list(t1, t2)
	local new_list = {}
	for _, v in ipairs(t1) do
		table.insert(new_list, v)
	end
	for _, v in ipairs(t2) do
		table.insert(new_list, v)
	end
	return new_list
end

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

function M.deep_copy(object)
	if type(object) ~= "table" then
		return object
	end

	local result = {}
	for key, value in pairs(object) do
		result[key] = M.deep_copy(value)
	end
	return result
end

function M.spread(template)
	return function(table)
		local result = {}
		for key, value in pairs(template) do
			result[key] = M.deep_copy(value) -- Note the deep copy!
		end

		for key, value in pairs(table) do
			result[key] = value
		end
		return result
	end
end
return M
