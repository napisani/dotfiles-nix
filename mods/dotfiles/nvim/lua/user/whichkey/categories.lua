-- <leader><leader>t which-key group: pick which file categories are enabled,
-- mirroring the shape of <leader><leader>s (directory scope).
local category = require("user.scope.category")

local M = {}

local function build_items()
	local items = {}
	for _, name in ipairs(category.list_names()) do
		table.insert(items, { category = name, text = name })
	end
	return items
end

local function format_item(item)
	local mark = category.is_enabled(item.category) and "[x]" or "[ ]"
	return mark .. " " .. item.category
end

local function open_picker()
	local ok, Snacks = pcall(require, "snacks")
	if not ok then
		return
	end

	Snacks.picker.pick({
		source = "toggle categories",
		items = build_items(),
		format_item = format_item,
		confirm = function(picker, item)
			if item then
				category.set_enabled(item.category, not category.is_enabled(item.category))
			end
			if picker and picker.close then
				picker:close()
			end
			-- No existing confirm action in this config redraws picker rows
			-- without closing (see spec risks); close + reopen trades a little
			-- flicker for reusing an already-known-working call shape.
			open_picker()
		end,
	})
end

function M.pick_categories()
	open_picker()
end

function M.reset_all()
	category.reset_all()
end

local normal_mappings = {
	{
		"<leader><leader>ta",
		function()
			M.pick_categories()
		end,
		desc = "toggle c(a)tegories",
	},
	{
		"<leader><leader>tx",
		function()
			M.reset_all()
		end,
		desc = "(x) reset categories",
	},
}

return {
	mapping_v = {},
	mapping_n = normal_mappings,
	mapping_shared = {},
}
