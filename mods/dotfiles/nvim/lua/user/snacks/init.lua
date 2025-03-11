local M = {}

M.opts = {
	-- your configuration comes here
	-- or leave it empty to use the default settings
	-- refer to the configuration section below
	bigfile = { enabled = false },
	dashboard = { enabled = false },
	explorer = { enabled = false },
	indent = { enabled = false },
	input = { enabled = false },
	picker = {
		enabled = true,
		layout = {
			layout = {
				backdrop = false,
				width = 0.90,
				min_width = 80,
				height = 0.90,
				min_height = 30,
				box = "vertical",
				border = "rounded",
				title = "{title} {live} {flags}",
				title_pos = "center",
				{ win = "preview", title = "{preview}", height = 0.4, border = "bottom" },
				{ win = "input", height = 1, border = "none" },
				{ win = "list", border = "top" },
			},
		},
		formatters = {
			file = {
				truncate = 130, -- truncate the file path to (roughly) this length
			},
		},
	},
	notifier = { enabled = false },
	quickfile = { enabled = false },
	scope = { enabled = false },
	scroll = { enabled = false },
	statuscolumn = { enabled = false },
	words = { enabled = false },

	zen = {
		toggles = { dim = false, git_signs = false, mini_diff_signs = false },
		win = {
			backdrop = { transparent = false, blend = 99 }, -- This needs to be 99, 100 results in same behaviour as default setup
		},
	},
}
return M
