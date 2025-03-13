local M = {}
---@param opts snacks.Config?
local get_opts = function(opts)
	return opts
end

M.opts = get_opts({
	bigfile = { enabled = true },

	dashboard = {
		enabled = true,
		preset = {

			header = [[
              __
  ___     ___    ___   __  __ /\_\    ___ ___    
 / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\  
/\ \/\ \/\  __//\ \_\ \ \ \_/ |\ \ \/\ \/\ \/\ \ 
\ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\
 \/_/\/_/\/____/\/___/  \/__/    \/_/\/_/\/_/\/_/
]],
		},
	},

	explorer = { enabled = false },

	indent = {
		enabled = false,
		indent = {
			char = "▏",
		},
		animate = {
			enabled = false,
		},
	},

	input = { enabled = true },

	picker = {
		enabled = true,
		ui_select = true,
		layout = function()
			-- return vim.o.columns >= 120 and "my_picker" or "my_picker_vertical"
			return "my_horizontal_picker"
		end,
		layouts = {
			my_horizontal_picker = {
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
		},
		formatters = {
			file = {
				truncate = 80, -- truncate the file path to (roughly) this length
			},
		},
		win = {
			input = {
				keys = {
					["p"] = {
						"history_back",
						mode = { "n" },
					},
					["n"] = {
						"history_forward",
						mode = { "n" },
					},
				},
			},
		},
		previewers = {
			diff = {
				builtin = false, -- use Neovim for previewing diffs (true) or use an external tool (false)
				cmd = { "delta" }, -- example to show a diff with delta
			},
		},
	},

	notifier = { enabled = true },

	quickfile = { enabled = false },

	scope = { enabled = false },

	scroll = { enabled = true },

	statuscolumn = { enabled = false },

	words = { enabled = false },

	zen = {
		toggles = { dim = false, git_signs = false, mini_diff_signs = false },
		win = {
			backdrop = { transparent = false, blend = 99 }, -- This needs to be 99, 100 results in same behaviour as default setup
		},
	},
})
return M
