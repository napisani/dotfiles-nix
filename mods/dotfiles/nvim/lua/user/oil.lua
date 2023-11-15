local status_ok, oil = pcall(require, "oil")
if not status_ok then
  vim.notify("oil not found")
	return
end
oil.setup()
