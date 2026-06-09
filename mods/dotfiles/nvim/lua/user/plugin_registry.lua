-- Central plugin registry
-- This file defines all plugin modules and their metadata.
-- It serves as the single source of truth for:
--   1. Loading plugin configurations in init.lua
--   2. Extracting keymaps in whichkey/plugins.lua
--
-- Each entry is simply a module path relative to lua/user/plugins/
-- Modules are automatically detected for keymaps by checking if they
-- export a get_keymaps() function
--
-- IMPORTANT: Order matters! Some plugins must load before others
-- (e.g., colorscheme and notify load early)

local M = {}

-- Ordered list of all plugin modules
-- This maintains the specific load order required for proper initialization
M.modules = {
	-- UI plugins (colorscheme and notify must load early)
	"ui.notify",
	"ui.colorscheme",
	-- Git plugins
	"git.diff",
	"git.gitsigns",
	"git.neogit",
	-- Navigation plugins
	"navigation.hop",
	-- Code plugins
	"code.treesitter",
	-- Editing plugins
	"editing.comment",
	"navigation.nvim-tree",
	-- UI plugins (remaining)
	"ui.colorizer",
	"ui.bufferline",
	"ui.lualine",
	"ui.indentline",
	-- AI plugins
	"ai.wiremux",
	"ai.vocal",
	"ai.vantage",
	-- Database plugins
	"database.dadbod",
	-- Navigation plugins (remaining)
	"navigation.tmux-nav",
	"navigation.oil",
	-- Editing plugins (remaining)
	"editing.eyeliner",
	-- Debug plugins
	"debug.nvim-dap",
	-- Util plugins
	"util.fff",
}

-- Get all plugin modules in proper load order
function M.get_all_modules()
	return M.modules
end

return M
