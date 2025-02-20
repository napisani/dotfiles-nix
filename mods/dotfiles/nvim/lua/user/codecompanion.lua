local ok, codecompanion = pcall(require, "codecompanion")
if not codecompanion then
	vim.notify("codecompanion not found", vim.log.levels.ERROR)
	return
end
codecompanion.setup({

	strategies = {
		chat = {
			keymaps = {
				send = {
					modes = { n = { "<CR>", "<C-g>" }, i = "<C-g>" },
				},

				watch = {
					modes = { n = "gW" },
				},
				next_chat = {
					modes = { n = "]c" },
				},
				previous_chat = {
					modes = { n = "[c" },
				},
			},
		},
	},
})
