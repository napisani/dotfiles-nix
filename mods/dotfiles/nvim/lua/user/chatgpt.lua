local status_ok, chatgpt = pcall(require, "chatgpt")
if not status_ok then
	vim.notify("chatgpt not found ")
	return
end
chatgpt.setup({
	api_key_cmd = 'echo "$OPENAI_KEY"',
	chat = {
		keymaps = {
			close = { "<leader>tq" },
		},
	},
})

