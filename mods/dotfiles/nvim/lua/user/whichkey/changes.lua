-- DEPRECATED: This module is now empty
--
-- All diffview keymaps have been moved to their respective plugin modules:
-- - Diffview keymaps: lua/user/plugins/git/diff.lua (get_keymaps function)
--
-- Plugin keymaps are automatically loaded by lua/user/whichkey/plugins.lua
-- which scans all plugin modules and extracts their get_keymaps() functions.
--
-- These empty tables are kept to maintain compatibility with the main whichkey.lua
-- which imports this module.

local normal_mappings = {}

local visual_mappings = {}

return {
	mapping_v = visual_mappings,
	mapping_n = normal_mappings,
	mapping_shared = {},
}
