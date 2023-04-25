-- local status_ok, nvim_rooter = pcall(require, "nvim-rooter")
-- if not status_ok then
--   vim.notify('could not import nvim-rooter')
--   return
-- end
-- nvim_rooter.setup()

local M = {}
local root_dir = vim.fn.getcwd()
function M.get_root_dir()
	return root_dir
end
return M
