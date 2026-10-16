local cwd = vim.fn.getcwd()
local old_flag = vim.env.NVIM_NO_PROJECT_CONFIG
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.fn.writefile({ "vim.g.project_config_test = true" }, root .. "/.nvim.lua")
vim.uv.chdir(root)
local manager = require("user.plugins.util.exrc_manager")
vim.env.NVIM_NO_PROJECT_CONFIG = "1"
manager.source_local_config()
assert(not vim.g.project_config_test, "explicit startup opt-out must skip project code")
vim.env.NVIM_NO_PROJECT_CONFIG = nil
manager.source_local_config()
assert(vim.g.project_config_test, "ordinary Neovim keeps normal project configuration")
vim.g.project_config_test = nil
vim.env.NVIM_NO_PROJECT_CONFIG = old_flag
vim.uv.chdir(cwd)
vim.fn.delete(root, "rf")
print("exrc_manager_spec: ok")
