-- Plugin keymap orchestrator
-- Loads keymaps from plugin modules defined in plugin_registry.lua

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

  return keymaps
end

-- Normalize keymap structure from various formats
local function normalize_keymaps(keymaps)
  local normalized = {
    normal = {},
    visual = {},
    shared = {},
  }

  -- Handle table format with mode keys
  if keymaps.normal or keymaps.visual or keymaps.shared then
    normalized.normal = keymaps.normal or {}
    normalized.visual = keymaps.visual or {}
    normalized.shared = keymaps.shared or {}
    return normalized
  end

  -- Handle flat array format - categorize by mode
  for _, keymap in ipairs(keymaps) do
    local mode = keymap.mode or "n"

    -- Determine which category this keymap belongs to
    if type(mode) == "table" then
      -- If mode is an array, check if it includes both n and v
      local has_n = vim.tbl_contains(mode, "n")
      local has_v = vim.tbl_contains(mode, "v") or vim.tbl_contains(mode, "x")

      if has_n and has_v then
        table.insert(normalized.shared, keymap)
      elseif has_n then
        table.insert(normalized.normal, keymap)
      elseif has_v then
        table.insert(normalized.visual, keymap)
      else
        -- Other modes (i, t, etc.) - treat as shared
        table.insert(normalized.shared, keymap)
      end
    elseif mode == "n" then
      table.insert(normalized.normal, keymap)
    elseif mode == "v" or mode == "x" then
      table.insert(normalized.visual, keymap)
    else
      -- Modes like insert, terminal, etc.
      table.insert(normalized.shared, keymap)
    end
  end

  return normalized
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
      local normalized = normalize_keymaps(keymaps)

      -- Merge keymaps into our collection
      vim.list_extend(all_keymaps.normal, normalized.normal)
      vim.list_extend(all_keymaps.visual, normalized.visual)
      vim.list_extend(all_keymaps.shared, normalized.shared)
    end
  end

  return all_keymaps
end

-- Get only normal mode keymaps (flat array)
function M.get_normal_keymaps()
  local keymaps = M.get_all_plugin_keymaps()
  local result = {}
  vim.list_extend(result, keymaps.normal)
  vim.list_extend(result, keymaps.shared)
  return result
end

-- Get only visual mode keymaps (flat array)
function M.get_visual_keymaps()
  local keymaps = M.get_all_plugin_keymaps()
  local result = {}
  vim.list_extend(result, keymaps.visual)
  vim.list_extend(result, keymaps.shared)
  return result
end

return M
