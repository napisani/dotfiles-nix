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

-- snacks.picker `format`: returns highlight chunks, not a string. Items here
-- have no `file`, so the default file formatter/previewer errors out.
local function format_item(item)
	local enabled = category.is_enabled(item.category)
	return {
		{ enabled and "[x] " or "[ ] ", enabled and "SnacksPickerToggle" or "SnacksPickerComment" },
		{ item.category, "SnacksPickerLabel" },
	}
end

local function open_picker()
	local ok, Snacks = pcall(require, "snacks")
	if not ok then
		return
	end

	Snacks.picker.pick({
		source = "toggle categories",
		items = build_items(),
		format = format_item,
		preview = "none",
		layout = { preset = "select" },
		actions = {
			-- Toggle the category under the cursor and re-render in place. The
			-- item list is static, so `update` is enough to redraw the marks --
			-- no finder re-run, no cursor jump, picker stays open.
			toggle_category = function(picker, item)
				if not item then
					return
				end
				category.set_enabled(item.category, not category.is_enabled(item.category))
				picker:update({ force = true })
			end,
		},
		win = {
			input = {
				keys = {
					["<Tab>"] = { "toggle_category", mode = { "i", "n" } },
				},
			},
			list = {
				keys = {
					["<Tab>"] = { "toggle_category", mode = { "n", "x" } },
				},
			},
		},
		-- <CR> just dismisses: toggling is done with <Tab>.
		confirm = function(picker)
			if picker and picker.close then
				picker:close()
			end
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
