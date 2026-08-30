-- Unified built-in and project scope picker used by <leader><leader>st.
local path = require("user.scope.path")
local category = require("user.scope.category")
local project = require("user.scope.project")

local M = {}

local function build_items()
	local items = {}
	for _, name in ipairs(category.list_names()) do
		table.insert(items, { scope_name = name, scope_kind = "category", text = name })
	end
	local project_scopes, errors = project.list_scopes()
	for _, error_message in ipairs(errors) do
		vim.notify("Invalid project scope: " .. error_message, vim.log.levels.WARN)
	end
	for _, scope in ipairs(project_scopes) do
		table.insert(items, { scope_name = scope.name, scope_kind = "project", text = scope.name })
	end
	return items
end

local function format_item(item)
	local active = path.active_scope_name() == item.scope_name
	return {
		{ active and "(*) " or "( ) ", active and "SnacksPickerToggle" or "SnacksPickerComment" },
		{ item.text, "SnacksPickerLabel" },
	}
end

function M.scope_items()
	return build_items()
end

function M.pick_categories(on_change)
	local ok, Snacks = pcall(require, "snacks")
	if not ok then
		return
	end

	Snacks.picker.pick({
		source = "project scopes",
		items = M.scope_items(),
		format = format_item,
		preview = "none",
		layout = { preset = "select" },
		confirm = function(picker, item)
			if item then
				local applied, err = project.select_scope(item.scope_name)
				if not applied then
					vim.notify("Could not select scope: " .. tostring(err), vim.log.levels.ERROR)
				else
					if on_change then
						on_change()
					end
				end
			end
			if picker and picker.close then
				picker:close()
			end
		end,
	})
end

function M.reset_all()
	path.clear_scopes()
end

return {
	mapping_v = {},
	mapping_n = {},
	mapping_shared = {},
	pick_categories = M.pick_categories,
	scope_items = M.scope_items,
	reset_all = M.reset_all,
}
