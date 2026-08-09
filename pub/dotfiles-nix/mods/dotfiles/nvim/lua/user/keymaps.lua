local opts = { noremap = true, silent = true }

--Remap space as leader key
vim.keymap.set("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "

-- Navigate buffers
vim.keymap.set("n", "<S-l>", ":bnext<CR>", opts)
vim.keymap.set("n", "<S-h>", ":bprevious<CR>", opts)

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
vim.keymap.set("n", "<C-_>", ":Commentary<CR>", opts)
vim.keymap.set("v", "<C-_>", ":Commentary<CR>", opts)

-- Alias for window leader
vim.keymap.set("n", "gw", ':call feedkeys("\\<lt>c-w>")<cr>', opts)

-- Hop keybindings
-- unmap default keybindings for s
vim.keymap.set({ "n", "x", "o" }, "s", "<Nop>", { silent = true })
vim.keymap.set({ "n", "x", "o" }, "S", "<cmd>HopWord<CR>", opts)
vim.keymap.set({ "n", "x", "o" }, "ss", "<cmd>HopWord<CR>", opts)
vim.keymap.set({ "n", "x", "o" }, "sv", "<cmd>HopVertical<CR>", opts)
vim.keymap.set({ "n", "x", "o" }, "sb", "<cmd>HopNodes<CR>", opts)
vim.keymap.set({ "n", "x", "o" }, "sl", "<cmd>HopCamelCaseCurrentLine<CR>", opts)
