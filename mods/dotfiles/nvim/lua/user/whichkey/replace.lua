local utils = require("user.utils")
local function prepare_search_replace(cmd, cursor_left, extra_cmd, copy)
	return function()
		if copy then
			vim.fn.feedkeys('"4y', "n")
		end
		vim.fn.feedkeys(cmd, "n")
		for _ = 1, cursor_left do
			-- press the enter key once
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Left>", true, true, true), "n", true)
		end
		if copy then
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-r>", true, true, true), "n", true)
			vim.fn.feedkeys("4", "n")
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Right>", true, true, true), "n", true)
		end

		if extra_cmd then
			vim.fn.feedkeys(extra_cmd, "n")
		end
	end
end

local common_search = {
	{ "<leader>r*", prepare_search_replace(":%s@<C-R>=expand('<cword>')<CR>@@gc", 3), desc = "(*)word" },
	{ "<leader>rb", prepare_search_replace(":%s@@@g", 3), desc = "(b)uffer" },
	{ "<leader>rB", prepare_search_replace(":%s@@@gc", 4), desc = "(B)uffer ask" },
	{ "<leader>rD", prepare_search_replace(":g!@@d", 2), desc = "(D)elete else" },
	{ "<leader>rQ", prepare_search_replace(":%s@@@gc", 4, ":cdo "), desc = "(Q)uicklist ask" },
	{ "<leader>rd", prepare_search_replace(":g@@d", 2), desc = "(d)elete" },
	{ "<leader>rl", prepare_search_replace(":s@@@g", 3), desc = "(l)line" },
	{ "<leader>rq", prepare_search_replace(":%s@@@g", 3, ":cdo "), desc = "(q)uicklist" },
}

local subvert_group = {
	{ "<leader><leader>r", group = "Subvert Replace" },
}

local replace_group = {
	{ "<leader>r", group = "Replace" },
}

local common_subvert = {
	{ "<leader><leader>r*", prepare_search_replace(":%Subs/<C-R>=expand('<cword>')<CR>//gc", 3), desc = "(*)word" },
	{ "<leader><leader>rb", prepare_search_replace(":%Subs///g", 3), desc = "(b)uffer" },
	{ "<leader><leader>rB", prepare_search_replace(":%Subs///gc", 4), desc = "(B)uffer ask" },
	{ "<leader><leader>rQ", prepare_search_replace(":%Subs///gc", 4, ":cdo "), desc = "(Q)uicklist ask" },
	{ "<leader><leader>rl", prepare_search_replace(":Subs///g", 3), desc = "(l)line" },
	{ "<leader><leader>rq", prepare_search_replace(":%Subs///g", 3, ":cdo "), desc = "(q)uicklist" },
}

local normal_mappings = utils.extend_lists(replace_group, common_search, subvert_group, common_subvert)

local visual_mappings = utils.extend_lists(
	replace_group,
	{
		{ "<leader>*rB", prepare_search_replace(":%s@<C-R>=expand('<cword>')<CR>@@gc", 3), desc = "(B)uffer ask" },
		{
			"<leader>*rQ",
			prepare_search_replace(":%s@<C-R>=expand('<cword>')<CR>@@gc", 3, ":cdo "),
			desc = "(Q)uicklist ask",
		},
		{ "<leader>*rb", prepare_search_replace(":%s@<C-R>=expand('<cword>')<CR>@@g", 2), desc = "(b)uffer" },
		{ "<leader>*rl", prepare_search_replace(":s@<C-R>=expand('<cword>')<CR>@@g", 2), desc = "(l)ine" },
		{
			"<leader>*rq",
			prepare_search_replace(":%s@<C-R>=expand('<cword>')<CR>@@g", 2, ":cdo "),
			desc = "(q)uicklist",
		},

		{ "<leader>rB", prepare_search_replace(":%s@@@gc", 4, "", true), desc = "(B)uffer ask" },
		{ "<leader>rQ", prepare_search_replace(":%s@@@gc", 4, ":cdo ", true), desc = "(Q)uicklist ask" },
		{ "<leader>rb", prepare_search_replace(":%s@@@g", 3, "", true), desc = "(b)uffer" },
		{ "<leader>rl", prepare_search_replace(":s@@@g", 3, "", true), desc = "(l)line" },
		{ "<leader>rq", prepare_search_replace(":%s@@@g", 3, ":cdo ", true), desc = "(q)uicklist" },

		{ "<leader>rV", prepare_search_replace(":s@@@gc", 4, "", false), desc = "(V)isual ask" },
		{ "<leader>rv", prepare_search_replace(":s@@@g", 3, "", false), desc = "(v)isual" },
	},

	subvert_group,
	{
		{ "<leader><leader>rB", prepare_search_replace(":%Subs///gc", 4, "", true), desc = "(B)uffer ask" },
		{ "<leader><leader>rQ", prepare_search_replace(":%Subs///gc", 4, ":cdo ", true), desc = "(Q)uicklist ask" },
		{ "<leader><leader>rb", prepare_search_replace(":%Subs///g", 3, "", true), desc = "(b)uffer" },
		{ "<leader><leader>rl", prepare_search_replace(":Subs///g", 3, "", true), desc = "(l)line" },
		{ "<leader><leader>rq", prepare_search_replace(":%Subs///g", 3, ":cdo ", true), desc = "(q)uicklist" },

		{ "<leader><leader>rV", prepare_search_replace(":Subs///gc", 4, "", false), desc = "(V)isual ask" },
		{ "<leader><leader>rv", prepare_search_replace(":Subs///g", 3, "", false), desc = "(v)isual" },
	}
)

return {
	v_mappings = visual_mappings,
	n_mappings = normal_mappings,
}
