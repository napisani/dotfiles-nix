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
  "code.blink",
  -- Editing plugins
  "editing.autopairs",
  "editing.comment",
  "navigation.nvim-tree",
  -- UI plugins (remaining)
  "ui.colorizer",
  "ui.bufferline",
  "ui.lualine",
  -- "ui.outline",
  "ui.indentline",
  -- AI plugins
  "ai.codecompanion",
  "ai.context_nvim",
  "ai.code_explain",
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
  -- "util.sidekick",  -- Commented out - plugin not currently available
}

-- Get all plugin modules in proper load order
function M.get_all_modules()
  return M.modules
end

-- Get plugin modules by category
function M.get_modules_by_category(category)
  local result = {}
  local prefix = category .. "."
  for _, module_path in ipairs(M.modules) do
    if vim.startswith(module_path, prefix) then
      table.insert(result, module_path)
    end
  end
  return result
end

return M
