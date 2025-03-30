local normal_mappings = {
	{ "<localleader>rC", "<cmd>SlimeConfig<cr>", desc = "Slime Config" },
	{ "<localleader>rr", "<Plug>SlimeSendCell<CR>", desc = "Slime Send Cell" },
}

local visual_mappings = {
	{ "<localleader>rr", ":<C-u>'<,'>SlimeSend<CR>", mode = "v", desc = "Slime Send Selection" },
}

return {
	mapping_v = visual_mappings,
	mapping_n = normal_mappings,
	mapping_shared = {},
}
