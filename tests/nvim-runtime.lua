local source = assert(arg[1], "Neovim configuration path required")
vim.opt.runtimepath:prepend(source)
require("user.runtime")
local path = vim.env.PATH
local data = vim.env.XDG_DATA_HOME
if not data or data == "" then
	data = vim.env.HOME .. "/.local/share"
end
assert(path:sub(1, #(data .. "/mise/shims:")) == data .. "/mise/shims:")
package.loaded["user.runtime"] = nil
require("user.runtime")
assert(vim.env.PATH == path, "runtime initialization duplicated PATH entries")
assert(vim.g.loaded_ruby_provider == 0, "Ruby provider must be disabled")
assert(vim.g.python3_host_prog == data .. "/dotfiles/nvim-python/bin/python")
vim.cmd([[python3 import vim, sys; vim.vars['native_provider_probe'] = sys.executable]])
assert(vim.g.native_provider_probe == vim.g.python3_host_prog, "wrong Python provider")
print("Native Neovim Python RPC, Ruby disablement and idempotent GUI PATH passed")
