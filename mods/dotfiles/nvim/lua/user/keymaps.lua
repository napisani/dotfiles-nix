local opts = { noremap = true, silent = true }

local term_opts = { silent = true }

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Modes
--   normal_mode = "n",
--   insert_mode = "i",
--   visual_mode = "v",
--   visual_block_mode = "x",
--   term_mode = "t",
--   command_mode = "c",

-- Navigate buffers
keymap("n", "<S-l>", ":bnext<CR>", opts)
keymap("n", "<S-h>", ":bprevious<CR>", opts)

-- Visual --
-- this used to work before opencode.nvim
-- Stay in indent mode
-- keymap("v", "<", "<gv", opts)
-- keymap("v", ">", ">gv", opts)

-- Stay in indent mode (fixed) works with opencode.nvim
vim.keymap.set("v", ">", function()
	vim.cmd("normal! >")
	vim.cmd("normal! gv")
end, { noremap = true, silent = true, desc = "Indent and keep selection" })

vim.keymap.set("v", "<", function()
	vim.cmd("normal! <")
	vim.cmd("normal! gv")
end, { noremap = true, silent = true, desc = "Unindent and keep selection" })

-- Commentary - comment
keymap("n", "<C-_>", ":Commentary<CR>", opts)
keymap("v", "<C-_>", ":Commentary<CR>", opts)

-- Alias for window leader
keymap("n", "gw", ':call feedkeys("\\<lt>c-w>")<cr>', opts)

-- Hop keybindings
-- unmap default keybindings for s
local noop = function() end
vim.keymap.set({ "n", "x", "o" }, "s", noop, { silent = true })
vim.keymap.set({ "n", "x", "o" }, "S", "<cmd>HopWord<CR>", opts)
vim.keymap.set({ "n", "x", "o" }, "ss", "<cmd>HopWord<CR>", opts)
vim.keymap.set({ "n", "x", "o" }, "sv", "<cmd>HopVertical<CR>", opts)
vim.keymap.set({ "n", "x", "o" }, "sb", "<cmd>HopNodes<CR>", opts)
vim.keymap.set({ "n", "x", "o" }, "sl", "<cmd>HopCamelCaseCurrentLine<CR>", opts)
