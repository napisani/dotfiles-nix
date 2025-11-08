local M = {}

function M.setup()
  local status_ok, neogit = pcall(require, "neogit")
  if not status_ok then
    vim.notify("neogit not found")
    return
  end

  neogit.setup({})
end

function M.get_keymaps()
  return {
    normal = {},
    visual = {},

    shared = {
      {
        "<leader>go",
        function()
          vim.cmd(":Neogit")
        end,
        desc = "Open neogit",
      },
    },
  }
end

return M
