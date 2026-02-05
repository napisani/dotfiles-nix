local utils = require("user.utils")

vim.cmd([[
  augroup _general_settings
    autocmd!
    autocmd FileType qf,help,man,lspinfo nnoremap <silent> <buffer> q :close<CR> 
    autocmd TextYankPost * silent!lua require('vim.highlight').on_yank({higroup = 'Visual', timeout = 200}) 
    autocmd BufWinEnter * :set formatoptions-=cro
    autocmd FileType qf set nobuflisted
  augroup end

  augroup _git
    autocmd!
    autocmd FileType gitcommit setlocal wrap
    autocmd FileType gitcommit setlocal spell
  augroup end

  augroup _markdown
    autocmd!
    autocmd FileType markdown setlocal wrap
    autocmd FileType markdown setlocal spell
  augroup end

  augroup _auto_resize
    autocmd!
    autocmd VimResized * tabdo wincmd = 
  augroup end

  augroup _alpha
    autocmd!
    autocmd User AlphaReady set showtabline=0 | autocmd BufUnload <buffer> set showtabline=2
  augroup end

  augroup _helm
    autocmd!
    autocmd BufRead,BufNewFile */templates/*.yml,helmfile*.yml set ft=helm
  augroup end

]])

local lsp_mason = require("user.lsp.mason")
-- efm - format on save
local lsp_fmt_group = vim.api.nvim_create_augroup("LspFormattingGroup", {})
vim.api.nvim_create_autocmd("BufWritePost", {
	group = lsp_fmt_group,
	callback = function(ev)
		-- fix imports
		-- lsp_mason.fix_all_imports()

		-- run formatters
		local efm = vim.lsp.get_clients({ name = "efm", bufnr = ev.buf })
		if vim.tbl_isempty(efm) then
			return
		end
		vim.lsp.buf.format({ name = "efm", timeout_ms = 10000 })
	end,
})

-- dadbod - enable auto complete for table names and other db assets
vim.api.nvim_create_autocmd("FileType", {
	desc = "dadbod completion",
	group = vim.api.nvim_create_augroup("dadbod_cmp", { clear = true }),
	pattern = { "sql", "mysql", "plsql" },
	callback = function()
		require("cmp").setup.buffer({ sources = { { name = "vim-dadbod-completion" } } })
	end,
})

-- add support for .env files
vim.filetype.add({
	extension = {
		env = "sh",
	},
	filename = {
		[".env"] = "sh",
	},
	pattern = {
		["%.env%.[%w_.-]+"] = "sh",
	},
})

-- Define a function to set slime cell delimiters
local function set_slime_cell_delimiter()
	local filetype = vim.bo.filetype
	if filetype == "javascript" then
		vim.b.slime_cell_delimiter = "\\/\\/ --"
	else
		vim.b.slime_cell_delimiter = "# --"
	end
end

-- Create an autocommand group for Slime cell delimiters
vim.api.nvim_create_augroup("SlimeCellDelimiters", { clear = true })

-- Add the autocommand to set the delimiter on file type change
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "*" },
	callback = set_slime_cell_delimiter,
})
-- Autoformat
-- augroup _lsp
--   autocmd!
--   autocmd BufWritePre * lua vim.lsp.buf.formatting()
-- augroup end

local project_autocmd_config = utils.get_project_config().autocmds or {}
if next(project_autocmd_config) ~= nil then
	local project_autocmd_group = vim.api.nvim_create_augroup("nvim_project_autocmds", { clear = true })
	for _, value in ipairs(project_autocmd_config) do
		local event = value.event
		local pattern = value.pattern
		local cmd = value.command
		if event == nil or cmd == nil then
			vim.notify("event and command are required for project autocmds", vim.log.levels.ERROR)
			return
		end

		vim.api.nvim_create_autocmd(event, {
			group = project_autocmd_group,
			pattern = pattern,
			callback = function()
				vim.cmd(cmd)
			end,
		})
	end
end
