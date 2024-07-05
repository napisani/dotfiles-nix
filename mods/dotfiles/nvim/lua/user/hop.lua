local status_ok, hop = pcall(require, "hop")
if not status_ok then
	vim.notify("hop not found ")
	return
end
hop.setup({
	multi_windows = true,
	-- keys = "etovxqpdygfblzhckisuran",
  keys = "fjdkslgheirutycnvmowa;qp",


  uppercase_labels = false,
  create_hl_autocmd = true,
})

-- background colors
-- local bg = '#83a598'
local bg = '#fabd2f'
-- local  bg = '#d3869b'
local fg = '#282828'
vim.cmd('highlight HopNextKey guifg=' .. fg .. ' guibg=' .. bg .. '  gui=bold')
vim.cmd('highlight HopNextKey1 guifg=' .. fg .. ' guibg=' .. bg .. '  gui=bold')
vim.cmd('highlight HopNextKey2 guifg=' .. fg .. ' guibg=' .. bg .. '  gui=bold')
