local source, plugins, file = assert(arg[1]), assert(arg[2]), assert(arg[3])
vim.opt.runtimepath:append(plugins .. "/nvim-lspconfig")
vim.opt.runtimepath:append(plugins .. "/efmls-configs-nvim")
vim.opt.runtimepath:append(plugins .. "/plenary.nvim")
vim.opt.runtimepath:prepend(source)
require("user.runtime")
assert(vim.fn.executable("nil") == 0, "fixture PATH must not provide nil")
local errors = {}
vim.notify = function(message, level)
	if level == vim.log.levels.ERROR then
		table.insert(errors, message)
	end
end
local servers = require("user.lsp.registry").servers()
assert(not vim.tbl_contains(servers, "nil_ls"), "uninstalled nil_ls was still enabled")
vim.lsp.enable(servers)
vim.cmd.edit(file)
vim.bo.filetype = "nix"
vim.wait(1000)
assert(#errors == 0, "missing server reported errors: " .. vim.inspect(errors))
assert(vim.v.errmsg == "", vim.v.errmsg)
print("Uninstalled servers are skipped without errors")
