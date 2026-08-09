local Snacks = require("snacks")

local package_group = "Find > "
local commands = {
	{

		"<cmd>lua require('snacks').picker.highlights()<cr>",
		description = package_group .. "Highlights",
	},
}

return {
	commands = commands,
}
