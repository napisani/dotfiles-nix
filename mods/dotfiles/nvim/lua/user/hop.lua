local status_ok, hop = pcall(require, "hop")
if not status_ok then
	vim.notify("hop not found ")
	return
end
hop.setup({
	multi_windows = true,
	keys = "etovxqpdygfblzhckisuran",
})
