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
