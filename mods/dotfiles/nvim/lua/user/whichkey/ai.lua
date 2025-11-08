-- Old Gp.nvim keymaps (commented out for reference)
-- These were replaced by CodeCompanion keymaps which are now in lua/user/plugins/ai/codecompanion.lua

-- CodeCompanion keymaps moved to lua/user/plugins/ai/codecompanion.lua
local mapping_n = {
	{ "<leader>a", group = "(a)i" },

	-- ContextNvim keymaps (not in codecompanion plugin)
	{ "<leader>aca", ":ContextNvim add_current<cr>", desc = "(A)dd context" },
	{ "<leader>acl", ":ContextNvim add_line_lsp_daig<cr>", desc = "(l)sp diag to context" },
	{ "<leader>acx", ":ContextNvim clear_manual<cr>", desc = "clear context" },
	{ "<leader>ap", ":ContextNvim insert_prompt<cr>", desc = "insert (p)rompt" },
	{ "<leader>fa", "<cmd>:ContextNvim find_context_manual<cr>", desc = "(a)i contexts" },
}

-- CodeCompanion keymaps moved to lua/user/plugins/ai/codecompanion.lua
local mapping_v = {
	{ "<leader>a", group = "(a)i" },

	-- ContextNvim keymaps (not in codecompanion plugin)
	{ "<leader>aca", ":<C-u>'<,'>ContextNvim add_current<cr>", desc = "(A)dd context" },

	{ "<leader>ar", group = "(r)run" },
}

return {
	mapping_n = mapping_n,
	mapping_v = mapping_v,
}
