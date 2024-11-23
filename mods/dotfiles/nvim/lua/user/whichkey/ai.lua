local mapping_n = {
	{ "<leader>t", group = "ChatGPT" },
	{ "<leader>ta", "<cmd>:GpAppend<cr>", desc = "(a)ppend results" },
	{ "<leader>tc", "<cmd>:GpChatNew vsplit<cr>", desc = "(c)reate new chat" },
	{ "<leader>ti", "<cmd>:GpPrepend<cr>", desc = "(i)nsert/prepend results" },
	{ "<leader>tI", "<cmd>:GpRewrite<cr>", desc = "(I)nline / rewrite results" },
	{ "<leader>tn", "<cmd>:GpEnew<cr>", desc = "(n)ew buffer with results" },
	{ "<leader>to", "<cmd>:GpChatToggle<cr>", desc = "(o)pen existing chat" },
	{ "<leader>tp", "<cmd>:GpPopup<cr>", desc = "(p)opupresults" },
	{ "<leader>tq", "<cmd>:GpChatToggle<cr>", desc = "(q)uit chat" },
	{ "<leader>a", group = "AI" },
	{ "<leader>aA", ":ContextNvim add_current<cr>", desc = "(A)dd context" },
	{ "<leader>al", ":ContextNvim add_line_lsp_daig<cr>", desc = "(l)sp diag to context" },
	{ "<leader>aX", ":ContextNvim clear_manual<cr>", desc = "clear context" },
	{ "<leader>ap", ":ContextNvim insert_prompt<cr>", desc = "insert (p)rompt" },

	{ "<leader>tr", group = "(r)run" },
	{ "<leader>tre", "<cmd>:GpExplain<cr>", desc = "(e)xplian" },
	{ "<leader>tri", "<cmd>:GpImplement<cr>", desc = "(i)mplement" },
	{ "<leader>trt", "<cmd>:GpUnitTests<cr>", desc = "add (t)ests" },
	{ "<leader>ts", "<cmd>:GpStop<cr>", desc = "(s)stop streaming results" },

	{ "<leader>lc", "<Plug>ContextCommentaryLine", desc = "(c)omment" },

	{ "<leader>fa", desc = "(a)i" },
	{ "<leader>fam", "<cmd>:ContextNvim find_context_manual<cr>", desc = "(m)anual contexts" },
	{ "<leader>fah", "<cmd>:ContextNvim find_context_history<cr>", desc = "(h)istory_contexts" },
}

local mapping_v = {
	{ "<leader>t", group = "ChatGPT" },
	{ "<leader>ta", ":<C-u>'<,'>GpAppend<cr>", desc = "(a)ppend results" },
	{ "<leader>tc", ":<C-u>'<,'>GpChatNew vsplit<cr>", desc = "(c)reate new chat" },
	{ "<leader>ti", ":<C-u>'<,'>GpPrepend<cr>", desc = "(i)nsert/prepend results" },
	{ "<leader>ti", ":<C-u>'<,'>GpRewrite<cr>", desc = "(I)nline / rewrite" },
	{ "<leader>tn", ":<C-u>'<,'>GpEnew<cr>", desc = "(n)ew buffer with results" },
	{ "<leader>to", ":<C-u>'<,'>GpChatToggle<cr>", desc = "(o)pen existing chat" },
	{ "<leader>tp", ":<C-u>'<,'>GpPopup<cr>", desc = "(p)opupresults" },
	{ "<leader>tq", ":<C-u>'<,'>GpChatToggle<cr>", desc = "(q)uit chat" },

	{ "<leader>a", group = "AI" },
	{ "<leader>aA", ":<C-u>'<,'>ContextNvim add_current<cr>", desc = "(A)dd context" },

	{ "<leader>tr", group = "(r)run" },
	{ "<leader>tre", ":<C-u>'<,'>GpExplain<cr>", desc = "(e)xplian" },
	{ "<leader>tri", ":<C-u>'<,'>GpImplement<cr>", desc = "(i)mplement" },
	{ "<leader>trt", ":<C-u>'<,'>GpUnitTests<cr>", desc = "add (t)ests" },
	{ "<leader>ts", "<cmd>:GpStop<cr>", desc = "(s)stop streaming results" },
}
return {
	mapping_n = mapping_n,
	mapping_v = mapping_v,
}
