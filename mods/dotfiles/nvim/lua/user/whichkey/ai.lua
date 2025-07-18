-- local mapping_n = {
-- 	{ "<leader>a", group = "(a)i" },
-- 	{ "<leader>ai", "<cmd>:GpAppend<cr>", desc = "(a)ppend results" },
-- 	{ "<leader>aa", "<cmd>:GpChatNew vsplit<cr>", desc = "(c)reate new chat" },
-- 	{ "<leader>ae", "<cmd>:GpRewrite<cr>", desc = "(I)nline / rewrite results" },
-- 	{ "<leader>ao", "<cmd>:GpChatToggle<cr>", desc = "(o)pen existing chat" },
-- 	{ "<leader>aq", "<cmd>:GpChatToggle<cr>", desc = "(q)uit chat" },
-- 	{ "<leader>aca", ":ContextNvim add_current<cr>", desc = "(A)dd context" },
-- 	{ "<leader>acl", ":ContextNvim add_line_lsp_daig<cr>", desc = "(l)sp diag to context" },
-- 	{ "<leader>acx", ":ContextNvim clear_manual<cr>", desc = "clear context" },
-- 	{ "<leader>ap", ":ContextNvim insert_prompt<cr>", desc = "insert (p)rompt" },

-- 	{ "<leader>tr", group = "(r)run" },
-- 	{ "<leader>are", "<cmd>:GpExplain<cr>", desc = "(e)xplian" },
-- 	{ "<leader>ari", "<cmd>:GpImplement<cr>", desc = "(i)mplement" },
-- 	{ "<leader>art", "<cmd>:GpUnitTests<cr>", desc = "add (t)ests" },
-- 	{ "<leader>as", "<cmd>:GpStop<cr>", desc = "(s)stop streaming results" },

-- 	{ "<leader>fa", "<cmd>:ContextNvim find_context_manual<cr>", desc = "(a)i contexts" },
-- }

-- local mapping_v = {
-- 	{ "<leader>a", group = "(a)i" },
-- 	{ "<leader>ai", ":<C-u>'<,'>GpAppend<cr>", desc = "(a)ppend results" },
-- 	{ "<leader>aa", ":<C-u>'<,'>GpChatNew vsplit<cr>", desc = "(c)reate new chat" },
-- 	{ "<leader>ae", ":<C-u>'<,'>GpRewrite<cr>", desc = "(I)nline / rewrite" },
-- 	{ "<leader>ao", ":<C-u>'<,'>GpChatToggle<cr>", desc = "(o)pen existing chat" },
-- 	{ "<leader>aq", ":<C-u>'<,'>GpChatToggle<cr>", desc = "(q)uit chat" },

-- 	{ "<leader>a", group = "AI" },
-- 	{ "<leader>aca", ":<C-u>'<,'>ContextNvim add_current<cr>", desc = "(A)dd context" },

-- 	{ "<leader>ar", group = "(r)run" },
-- 	{ "<leader>are", ":<C-u>'<,'>GpExplain<cr>", desc = "(e)xplian" },
-- 	{ "<leader>ari", ":<C-u>'<,'>GpImplement<cr>", desc = "(i)mplement" },
-- 	{ "<leader>art", ":<C-u>'<,'>GpUnitTests<cr>", desc = "add (t)ests" },
-- 	{ "<leader>as", "<cmd>:GpStop<cr>", desc = "(s)stop streaming results" },
-- }

local Snacks = require("snacks")
local snacks_find_files = require("user.snacks.find_files")
local snacks_git_files = require("user.snacks.git_files")
local snacks_ai_context = require("user.snacks.ai_context_files")

local mapping_n = {
	{ "<leader>a", group = "(a)i" },
	{ "<leader>aa", "<cmd>:CodeCompanionChat<cr>", desc = "(a)dd to chat" },
	{ "<leader>aA", "<cmd>:CodeCompanionActions<cr>", desc = "(A)ctions" },
	{ "<leader>ae", "<cmd>:CodeCompanion<cr>", desc = "(I)nline / rewrite results" },
	{ "<leader>ao", "<cmd>:CodeCompanionChat Toggle<cr>", desc = "(o)pen existing chat" },
	{ "<leader>aq", "<cmd>:CodeCompanionChat Toggle<cr>", desc = "(q)uit chat" },
	{ "<leader>aca", ":ContextNvim add_current<cr>", desc = "(A)dd context" },
	{ "<leader>acl", ":ContextNvim add_line_lsp_daig<cr>", desc = "(l)sp diag to context" },
	{ "<leader>acx", ":ContextNvim clear_manual<cr>", desc = "clear context" },
	{ "<leader>ap", ":ContextNvim insert_prompt<cr>", desc = "insert (p)rompt" },
	{ "<leader>aw", desc = "s(w)itch adapter" },

	{ "<leader>tr", group = "(r)run" },
	-- { "<leader>are", "<cmd>:GpExplain<cr>", desc = "(e)xplian" },
	-- { "<leader>ari", "<cmd>:GpImplement<cr>", desc = "(i)mplement" },
	-- { "<leader>art", "<cmd>:GpUnitTests<cr>", desc = "add (t)ests" },
	-- { "<leader>as", "<cmd>:GpStop<cr>", desc = "(s)stop streaming results" },

	{ "<leader>fa", "<cmd>:ContextNvim find_context_manual<cr>", desc = "(a)i contexts" },
	{ "<leader>af", group = "(f)ind context" },

	{
		"<leader>afd",
		function()
			snacks_ai_context.add_file_to_chat(snacks_git_files.git_changed_files)
		end,
		desc = "(d)iff git files",
	},

	{
		"<leader>afe",
		function()
			snacks_ai_context.add_file_to_chat(Snacks.picker.buffers)
		end,
		desc = "Buffers",
	},

	{
		"<leader>afD",
		function()
			snacks_ai_context.add_file_to_chat(snacks_git_files.git_changed_cmp_base_branch)
		end,
		desc = "diff git (D)iff",
	},

	{
		"<leader>afC",
		function()
			snacks_ai_context.add_file_to_chat(snacks_git_files.git_conflicted_files)
		end,
		desc = "(C)onflicted files",
	},

	{
		"<leader>afr",
		function()
			snacks_ai_context.add_file_to_chat(snacks_find_files.find_files_from_root)
		end,
		desc = "files from (r)oot",
	},

	{
		"<leader>aft",
		function()
			snacks_ai_context.add_file_to_chat(Snacks.picker.git_files)
		end,
		desc = "gi(t) files",
	},
	{
		"<leader>afp",
		function()
			snacks_ai_context.add_file_to_chat(snacks_find_files.find_path_files)
		end,
		desc = "(p)ath files",
	},
}

local mapping_v = {
	{ "<leader>a", group = "(a)i" },
	-- { "<leader>ai", ":<C-u>'<,'>GpAppend<cr>", desc = "(a)ppend results" },
	{ "<leader>aa", ":<C-u>'<,'>CodeCompanionChat Add<cr>", desc = "(c)reate new chat" },
	{ "<leader>aA", ":<C-u>'<,'>CodeCompanionActions<cr>", desc = "(A)ctions" },
	{ "<leader>ae", ":<C-u>'<,'>CodeCompanion<cr>", desc = "(I)nline / rewrite" },
	{ "<leader>ao", ":<C-u>'<,'>CodeCompanionChat Add<cr>", desc = "(o)pen existing chat" },
	{ "<leader>aq", ":<C-u>'<,'>CodeCompanionChat Toggle<cr>", desc = "(q)uit chat" },

	{ "<leader>a", group = "AI" },
	{ "<leader>aca", ":<C-u>'<,'>ContextNvim add_current<cr>", desc = "(A)dd context" },

	{ "<leader>ar", group = "(r)run" },
	-- { "<leader>are", ":<C-u>'<,'>GpExplain<cr>", desc = "(e)xplian" },
	-- { "<leader>ari", ":<C-u>'<,'>GpImplement<cr>", desc = "(i)mplement" },
	-- { "<leader>art", ":<C-u>'<,'>GpUnitTests<cr>", desc = "add (t)ests" },
	-- { "<leader>as", "<cmd>:GpStop<cr>", desc = "(s)stop streaming results" },
}
return {
	mapping_n = mapping_n,
	mapping_v = mapping_v,
}
