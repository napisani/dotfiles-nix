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
local colorscheme = "kanagawa"
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
vim.cmd("colorscheme kanagawa")
local default_colors = require("kanagawa.colors").setup()
-- local overrides = {
-- override existing hl-groups, the new keywords are merged with existing ones
--    Visual = { bg = default_colors.waveBlue2 },
-- }
local overrides = function(colors) -- add/modify highlights
	return {}
	-- return { Visual = { bg = colors.waveBlue2 } }
end
require("kanagawa").setup({ overrides = overrides })
