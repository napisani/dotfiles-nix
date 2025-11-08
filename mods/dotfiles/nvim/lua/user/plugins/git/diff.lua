local M = {}

function M.setup()
	-- Create a new scratch buffer
	vim.api.nvim_create_user_command("NewScratchBuf", function()
		vim.cmd([[
      execute 'vsplit | enew'
      setlocal buftype=nofile
      setlocal bufhidden=hide
      setlocal noswapfile
    ]])
	end, { nargs = 0 })

	-- Compare clipboard to current buffer
	vim.api.nvim_create_user_command("CompareClipboard", function()
		local ftype = vim.api.nvim_eval("&filetype") -- original filetype
		vim.cmd([[
      tabnew %
      NewScratchBuf
      normal! P
      windo diffthis
    ]])
		vim.cmd("set filetype=" .. ftype)
	end, { nargs = 0 })

	-- Compare clipboard to visual selection
	vim.api.nvim_create_user_command("CompareClipboardSelection", function()
		vim.cmd([[
      " yank visual selection to z register
      normal! gv"zy
      " open new tab, set options to prevent save prompt when closing
      execute 'tabnew | setlocal buftype=nofile bufhidden=hide noswapfile'
      " paste z register into new buffer
      normal! V"zp
      NewScratchBuf
      normal! Vp
      windo diffthis
    ]])
	end, {
		nargs = 0,
		range = true,
	})

	-- improve the the diff presentation
	vim.o.diffopt = "internal,filler,closeoff,indent-heuristic,linematch:60,algorithm:histogram"
end

-- local function is_diffview_open()
-- 	local ok, diffview_lib = pcall(require, "diffview.lib")
-- 	if not ok then
-- 		return false
-- 	end
-- 	return diffview_lib.get_current_view() ~= nil
-- end

-- local status_ok, gitsigns = pcall(require, "gitsigns")
-- if not status_ok then
-- 	vim.notify("gitsigns not found")
-- 	return
-- end

function M.get_keymaps()
	local utils = require("user.utils")

	return {
		normal = {
			{ "<leader>c", group = "Changes" },

			{
				"<leader>cr",
				function()
					vim.cmd("DiffviewOpen " .. utils.get_git_ref())
				end,
				desc = "compare to ref",
			},

			{ "<leader>cB", "<Cmd>:G blame<CR>", desc = "Blame" },
			{ "<leader>cH", "<Cmd>:DiffviewOpen HEAD<CR>", desc = "diff (H)ead" },
			{ "<leader>ch", "<Cmd>:DiffviewFileHistory<CR>", desc = "(h)istory" },
			{ "<leader>co", "<Cmd>:DiffviewOpen<CR>", desc = "Open" },
			{ "<leader>cq", "<Cmd>:DiffviewClose<CR>", desc = "DiffviewClose" },
			{ "<leader>cx", '<Cmd>call feedkeys("dx")<CR>', desc = "Choose DELETE" },

			{ "<leader>cf", group = "(F)ile" },
			{ "<leader>cfH", "<Cmd>:DiffviewOpen HEAD -- %<CR>", desc = "diff (H)ead" },
			{
				"<leader>cfr",
				function()
					local ref = utils.get_git_ref()
					vim.cmd("DiffviewOpen " .. ref .. " -- %")
				end,
				desc = "compare to ref",
			},
			{
				"<leader>cff",
				"<cmd>lua require('user.snacks.compare').find_file_from_root_to_compare_to()<CR>",
				desc = "(f)ile",
			},
			{ "<leader>cfh", "<Cmd>:DiffviewFileHistory --follow %<CR>", desc = "(h)istory" },

			-- changes
			{ "<leader>cfc", "<cmd>CompareClipboard<cr>", desc = "compare (c)lipboard" },
		},

		visual = {
			{ "<leader>c", group = "Changes" },
			{ "<leader>cc", "<esc><cmd>CompareClipboardSelection<cr>", desc = "compare (c)lipboard" },
			{
				"<leader>ch",
				"<Esc><Cmd>'<,'>DiffviewFileHistory --follow<CR>",
				desc = "(h)istory",
			},
		},

		shared = {},
	}
end

return M
