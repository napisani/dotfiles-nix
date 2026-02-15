-- Enable secure external rc files
vim.opt.exrc = true
-- Also enable secure mode when using exrc for security
vim.opt.secure = true

-- Load project-local config early
local exrc_manager = require("user.plugins.util.exrc_manager")
exrc_manager.source_local_config()

-- Core configuration
require("user.options")
require("user.keymaps")
require("user.lazy")
require("user.lsp")

-- Initialize modular plugins from registry
-- The registry maintains proper load order (e.g., colorscheme and notify load early)
local registry = require("user.plugin_registry")
local plugin_modules = registry.get_all_modules()

for _, module_path in ipairs(plugin_modules) do
	local ok, plugin = pcall(require, "user.plugins." .. module_path)
	if ok and type(plugin.setup) == "function" then
		plugin.setup()
	end
end

-- Which-key setup (loads all keymaps including from modular plugins)
require("user.whichkey.whichkey")

-- Autocommands load after which-key
require("user.autocommands")

-- Finalize exrc manager setup
exrc_manager.setup()
