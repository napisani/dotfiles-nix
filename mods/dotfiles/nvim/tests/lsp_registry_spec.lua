local config = vim.fn.getcwd() .. "/pub/dotfiles-nix/mods/dotfiles/nvim"
vim.opt.rtp:prepend(config)
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.cmd.cd(root)
local registry = require("user.lsp.registry")
assert(vim.tbl_contains(registry.servers(), "vtsls"))
assert(not vim.tbl_contains(registry.servers(), "denols"))
for _, name in ipairs({ "vtsls", "denols", "basedpyright", "pyright", "pylsp", "ruff" }) do
	assert(registry.heavy[name], name .. " is not classified for deferred startup and idle sleep")
end
assert(not registry.heavy.efm, "lightweight formatting was classified as heavyweight")
assert(vim.tbl_contains(registry.configured, "vtsls") and vim.tbl_contains(registry.configured, "denols"))
vim.fn.writefile({ "{}" }, root .. "/deno.json")
assert(vim.tbl_contains(registry.servers(), "denols"))
assert(not vim.tbl_contains(registry.servers(), "vtsls"), "Deno selection enabled both TypeScript implementations")
vim.cmd.cd("/")
vim.fn.delete(root, "rf")
print("lsp_registry_spec: ok")
