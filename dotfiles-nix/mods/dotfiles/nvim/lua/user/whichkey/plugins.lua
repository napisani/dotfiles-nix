-- Plugin keymap orchestrator
-- Loads structured keymaps from plugin modules defined in plugin_registry.lua

local M = {}
local registry = require("user.plugin_registry")

-- Load a single plugin module and extract its keymaps
local function load_plugin_keymaps(module_path)
	local ok, plugin = pcall(require, "user.plugins." .. module_path)
	if not ok then
		vim.notify(
			string.format("Failed to load plugin module: user.plugins.%s", module_path),
			vim.log.levels.WARN
		)
		return nil
	end

	if type(plugin.get_keymaps) ~= "function" then
		-- Plugin doesn't export keymaps, skip silently
		return nil
	end

	local keymaps = plugin.get_keymaps()
	if not keymaps then
		return nil
	end

	if not (keymaps.normal or keymaps.visual or keymaps.shared) then
		vim.notify(
			string.format("Plugin module user.plugins.%s returned unsupported keymap format", module_path),
			vim.log.levels.WARN
		)
		return nil
	end

	return keymaps
end

-- Get all plugin keymaps organized by mode
function M.get_all_plugin_keymaps()
	local all_keymaps = {
		normal = {},
		visual = {},
		shared = {},
	}

	-- Load keymaps from all registered plugin modules
	-- Dynamically detect which modules have get_keymaps() function
	local modules = registry.get_all_modules()
	for _, module_path in ipairs(modules) do
		local keymaps = load_plugin_keymaps(module_path)

		if keymaps then
			vim.list_extend(all_keymaps.normal, keymaps.normal or {})
			vim.list_extend(all_keymaps.visual, keymaps.visual or {})
			vim.list_extend(all_keymaps.shared, keymaps.shared or {})
		end
	end

	return all_keymaps
end

-- Get only normal mode keymaps (flat array)
function M.get_normal_keymaps(keymaps)
	keymaps = keymaps or M.get_all_plugin_keymaps()
	local result = {}
	vim.list_extend(result, keymaps.normal)
	vim.list_extend(result, keymaps.shared)
	return result
end

-- Get only visual mode keymaps (flat array)
function M.get_visual_keymaps(keymaps)
	keymaps = keymaps or M.get_all_plugin_keymaps()
	local result = {}
	vim.list_extend(result, keymaps.visual)
	vim.list_extend(result, keymaps.shared)
	return result
end

return M
