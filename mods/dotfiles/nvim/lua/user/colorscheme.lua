-- other color themes available
-- darcula-solid
-- darcula
-- darkplus
-- tokyonight
-- gruvbox
-- nord
-- local colorscheme = "darcula"
-- local colorscheme = "tokyonight"
-- local colorscheme = "nord"
-- local colorscheme = "gruvbox"
-- tokyo settings
vim.cmd("let g:tokyonight_style = 'night'")
vim.cmd("let g:tokyonight_enable_italic = 0") -- available: night, storm

-- gruvbox settings
vim.cmd("let g:background='dark'")

-- nord
vim.cmd("let g:nord_contrast = v:true")
vim.cmd("let g:nord_borders = v:true")
vim.cmd("let g:nord_disable_background = v:false")
vim.cmd("let g:nord_italic = v:false")
vim.cmd("let g:nord_uniform_diff_background = v:true")
vim.cmd("let g:nord_bold = v:false")

-- kanagawa
require("kanagawa").setup({
	-- run :KanagawaCompile to compile the colorscheme
	-- compile = true,
	overrides = function(colors)
		local theme = colors.theme
		local utils = require("user.utils")
		utils.debug_log(theme)
		return {
			NormalFloat = { bg = "none" },
			FloatBorder = { bg = "none" },
			FloatTitle = { bg = "none" },

			-- Save an hlgroup with dark background and dimmed foreground
			-- so that you can use it where your still want darker windows.
			-- E.g.: autocmd TermOpen * setlocal winhighlight=Normal:NormalDark
			NormalDark = { fg = theme.ui.fg_dim, bg = theme.ui.bg_m3 },

			-- Popular plugins that open floats will link to NormalFloat by default;
			-- set their background accordingly if you wish to keep them dark and borderless
			LazyNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },
			MasonNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },
			-- Assign a static color to strings
			-- String = { fg = colors.palette.carpYellow, italic = true },
			-- -- theme colors will update dynamically when you change theme!
			-- SomePluginHl = { fg = colors.theme.syn.type, bold = true },

			SnacksPickerDir = { fg = colors.theme.ui.fg },
			SnacksPickerFile = { fg = colors.theme.ui.fg },
			SnacksIndentScope = { fg = colors.palette.springViolet1 },
		}
	end,
})

vim.cmd("colorscheme kanagawa")
