local scopes = require("user.snacks.scope")
local find_files = require("user.snacks.find_files")
local normal_mappings = {
	{
		"<leader><leader>sa",
		function()
			find_files.pick_scopes()
		end,
		desc = "(a)dd scope",
	},
	{
		"<leader><leader>sx",
		function()
			scopes.clear_scopes()
		end,
		desc = "(x) clear scopes",
	},
}

return {
	mapping_v = {},
	mapping_n = normal_mappings,
	mapping_shared = {},
}
