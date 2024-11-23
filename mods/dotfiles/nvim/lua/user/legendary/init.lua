local utils = require("user.utils")
local whichkey_maps = require("user.whichkey.whichkey")

local keymappings = {}
local group = ""
for _, mapping in ipairs(whichkey_maps.mapping_n) do
	if mapping.group ~= nil then
		group = mapping.group .. " > "
	else
		table.insert(keymappings, vim.tbl_extend("force", mapping, { desc = group .. (mapping.desc or "") }))
	end
end

local commands =
	utils.extend_lists(require("user.legendary.package_manage").commands, require("user.legendary.ai").commands)

require("legendary").setup({
	extensions = {
		lazy_nvim = true,
		diffview = true,
		which_key = false,
	},
	keymaps = keymappings,
	commands = commands,

	-- -- Use the custom Telescope picker
	-- select_prompt = nil, -- Use default Telescope prompt
	-- formatter = nil, -- Use default Telescope formatter
})
