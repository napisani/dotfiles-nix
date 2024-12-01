local mapping_n = {
	{ "<leader>a", group = "(a)i" },
	{ "<leader>ai", "<cmd>:GpAppend<cr>", desc = "(a)ppend results" },
	{ "<leader>aa", "<cmd>:GpChatNew vsplit<cr>", desc = "(c)reate new chat" },
	{ "<leader>ae", "<cmd>:GpRewrite<cr>", desc = "(I)nline / rewrite results" },
	{ "<leader>ao", "<cmd>:GpChatToggle<cr>", desc = "(o)pen existing chat" },
	{ "<leader>aq", "<cmd>:GpChatToggle<cr>", desc = "(q)uit chat" },
	{ "<leader>aca", ":ContextNvim add_current<cr>", desc = "(A)dd context" },
	{ "<leader>acl", ":ContextNvim add_line_lsp_daig<cr>", desc = "(l)sp diag to context" },
	{ "<leader>acx", ":ContextNvim clear_manual<cr>", desc = "clear context" },
	{ "<leader>ap", ":ContextNvim insert_prompt<cr>", desc = "insert (p)rompt" },

	{ "<leader>tr", group = "(r)run" },
	{ "<leader>are", "<cmd>:GpExplain<cr>", desc = "(e)xplian" },
	{ "<leader>ari", "<cmd>:GpImplement<cr>", desc = "(i)mplement" },
	{ "<leader>art", "<cmd>:GpUnitTests<cr>", desc = "add (t)ests" },
	{ "<leader>as", "<cmd>:GpStop<cr>", desc = "(s)stop streaming results" },

	{ "<leader>fa", "<cmd>:ContextNvim find_context_manual<cr>", desc = "(a)i contexts" },
}

local mapping_v = {
	{ "<leader>a", group = "(a)i" },
	{ "<leader>ai", ":<C-u>'<,'>GpAppend<cr>", desc = "(a)ppend results" },
	{ "<leader>aa", ":<C-u>'<,'>GpChatNew vsplit<cr>", desc = "(c)reate new chat" },
	{ "<leader>ae", ":<C-u>'<,'>GpRewrite<cr>", desc = "(I)nline / rewrite" },
	{ "<leader>ao", ":<C-u>'<,'>GpChatToggle<cr>", desc = "(o)pen existing chat" },
	{ "<leader>aq", ":<C-u>'<,'>GpChatToggle<cr>", desc = "(q)uit chat" },

	{ "<leader>a", group = "AI" },
	{ "<leader>aca", ":<C-u>'<,'>ContextNvim add_current<cr>", desc = "(A)dd context" },

	{ "<leader>ar", group = "(r)run" },
	{ "<leader>are", ":<C-u>'<,'>GpExplain<cr>", desc = "(e)xplian" },
	{ "<leader>ari", ":<C-u>'<,'>GpImplement<cr>", desc = "(i)mplement" },
	{ "<leader>art", ":<C-u>'<,'>GpUnitTests<cr>", desc = "add (t)ests" },
	{ "<leader>as", "<cmd>:GpStop<cr>", desc = "(s)stop streaming results" },
}
return {
	mapping_n = mapping_n,
	mapping_v = mapping_v,
}
