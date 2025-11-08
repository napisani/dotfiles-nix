local M = {}

function M.setup()
  local oil_ok, oil = pcall(require, "oil")
  if not oil_ok then
    vim.notify("oil not found")
    return
  end

  oil.setup({
    view_options = {
      show_hidden = true,
    },
  })
end

function M.get_keymaps()
  return {
    normal = {},
    visual = {},
    shared = {},
  }
end

return M
