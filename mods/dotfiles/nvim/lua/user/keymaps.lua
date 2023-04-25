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

-- Normal --
-- Better window navigation
--keymap("n", "<C-h>", "<C-w>h", opts)
--keymap("n", "<C-j>", "<C-w>j", opts)
--keymap("n", "<C-k>", "<C-w>k", opts)
--keymap("n", "<C-l>", "<C-w>l", opts)

-- Resize with arrows
keymap("n", "<C-Up>", ":resize -2<CR>", opts)
keymap("n", "<C-Down>", ":resize +2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Navigate buffers
keymap("n", "<S-l>", ":bnext<CR>", opts)
keymap("n", "<S-h>", ":bprevious<CR>", opts)

-- Move text up and down
--keymap("n", "<A-j>", "<Esc>:m .+1<CR>==gi", opts)
--keymap("n", "<A-k>", "<Esc>:m .-2<CR>==gi", opts)

-- Insert --
-- Press jk fast to exit insert mode
--keymap("i", "jk", "<ESC>", opts)
--keymap("i", "kj", "<ESC>", opts)

-- Visual --
-- Stay in indent mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Move text up and down
--keymap("v", "<A-j>", ":m .+1<CR>==", opts)
--keymap("v", "<A-k>", ":m .-2<CR>==", opts)
--keymap("v", "p", '"_dP', opts)

-- Visual Block --
-- Move text up and down
--keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
--keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
--keymap("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
--keymap("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)

-- Terminal --
-- Better terminal navigation
-- keymap("t", "<C-h>", "<C-\\><C-N><C-w>h", term_opts)
-- keymap("t", "<C-j>", "<C-\\><C-N><C-w>j", term_opts)
-- keymap("t", "<C-k>", "<C-\\><C-N><C-w>k", term_opts)
-- keymap("t", "<C-l>", "<C-\\><C-N><C-w>l", term_opts)

-- Commentary - comment
keymap("n", "<C-_>", ":Commentary<CR>", opts)
keymap("v", "<C-_>", ":Commentary<CR>", opts)

-- Search files
keymap("n", "<C-S-T>", ":Commentary<CR>", opts)

-- Alias for window leader
keymap("n", "gw", ':call feedkeys("\\<lt>c-w>")<cr>', opts)


-- keybinding to refresh vim config
keymap("n", "<leader>vr", ":source $MYVIMRC<CR>", opts)
keymap("n", "s", "<cmd>HopWord<CR>", opts)



-- keymap("n", "<leader>dc", "<Cmd>lua require'dap'.continue()<CR>", opts)
-- keymap("n", "<leader>dj", "<Cmd>lua require'dap'.step_over()<CR>", opts)
-- keymap("n", "<leader>dh", "<Cmd>lua require'dap'.step_into()<CR>", opts)
-- keymap("n", "<leader>dk", "<Cmd>lua require'dap'.step_out()<CR>", opts)
-- keymap("n", "<leader>db", "<Cmd>lua require'dap'.toggle_breakpoint()<CR>", opts)
-- keymap("n", "<leader>dB", "<Cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>", opts)
-- keymap("n", "<leader>dp", "<Cmd>lua require'dap'.set_breakpoint(vim.fn.input(nil, nil, vim.fn.input('Log point message: ')))<CR>", opts)
-- keymap("n", "<leader>dr", "<Cmd>lua require'dap'.repl.open()<CR>", opts)
-- keymap("n", "<leader>dl", "<Cmd>lua require'dap'.run_last()<CR>", opts)
