local status_ok, search_rules = pcall(require, "nvim-search-rules")
if not status_ok then
  vim.notify("nvim-search-rules not found ")
  return
end
-- search_rules.setup({})
-- local rooter = require("user.nvim-rooter")
-- globs = search_rules.get_ignore_globs({'.gitignore', '.nvimignore'}, rooter.get_root_dir())
-- require('user.utils').print(globs)
