local status_ok, commentstring = pcall(require, "ts_context_commentstring")
if not status_ok then
	vim.notify("ts_context_commentstring not found")
	return
end

commentstring.setup({
	enable = true,
})
