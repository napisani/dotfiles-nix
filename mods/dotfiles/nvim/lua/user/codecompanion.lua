local ok, codecompanion = pcall(require, "codecompanion")
if not codecompanion then
	vim.notify("codecompanion not found", vim.log.levels.ERROR)
	return
end
codecompanion.setup({

	adapters = {
		copilot = function()
			return require("codecompanion.adapters").extend("copilot", {
				schema = {
					model = {
						default = "claude-3.7-sonnet",
					},
				},
			})
		end,
	},

	strategies = {
		inline = {
			-- adapter = "openai",
		},
		chat = {
			-- adapter = "anthropic",

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
