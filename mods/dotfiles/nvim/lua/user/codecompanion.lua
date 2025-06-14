local ok, codecompanion = pcall(require, "codecompanion")
if not codecompanion then
	vim.notify("codecompanion not found", vim.log.levels.ERROR)
	return
end

local project_utils = require("user._project_utils")
local proj_conf = project_utils.get_project_config().codecompanion or {}

local prompt_library = proj_conf.prompt_library or {}

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

				debug = {
					modes = { n = "gD" },
					description = "Debug the current chat",
				},

				goto_file_under_cursor = {
					modes = { n = "gd" },
				},
				change_adapter = {
					modes = { n = "<leader>aw" },
				},
			},
		},
	},
	prompt_library = vim.tbl_extend("force", {}, prompt_library),
})
