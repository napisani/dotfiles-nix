
-- RUST DAP
local M = {}
local status_ok_rt, rt_dap = pcall(require, "rust-tools.dap")
if status_ok_rt then
  function M.run_rust()
    vim.notify("starting")
    rt_dap.start({
      executableArgs = {
        "/Users/nick/.config/nvim/lua/user/plugins.lua",
      },
      cargoArgs = {
        "run",
      },
    })
  end
end

