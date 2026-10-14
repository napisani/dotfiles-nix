local api = vim.api
local config = vim.fn.getcwd() .. "/pub/dotfiles-nix/mods/dotfiles/nvim"
vim.opt.rtp:prepend(config)
vim.g.mapleader = " "
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
root = assert(vim.uv.fs_realpath(root))
vim.fn.writefile({ "const value = 1;", "value;" }, root .. "/source.ts")
vim.fn.writefile({ "value = 1", "value" }, root .. "/source.py")
local servers = { "vtsls", "basedpyright" }
for _, name in ipairs(servers) do
	vim.lsp.config(name, {
		cmd = { vim.fn.exepath("python3"), config .. "/tests/fixtures/idle_lsp.py", "normal", "0.2" },
		filetypes = name == "vtsls" and { "typescript" } or { "python" },
		root_dir = root,
		exit_timeout = 100,
	})
end
require("user.lsp.attach").setup()
local lifecycle = require("user.lsp.lifecycle")
lifecycle.setup({ servers = servers, start_timeout_ms = 2000 })
vim.cmd.edit(root .. "/source.ts")
assert(vim.fn.maparg("<leader>li", "n", false, true).callback, "cold server-specific action has no mapping")
api.nvim_win_set_cursor(0, { 2, 0 })
api.nvim_feedkeys("gd", "xt", false)
assert(vim.lsp.is_enabled("vtsls"), "cold definition key did not initialize TypeScript")
assert(api.nvim_win_get_cursor(0)[1] == 2, "cold navigation blocked until initialization")
assert(
	vim.wait(3000, function()
		return api.nvim_win_get_cursor(0)[1] == 1
	end),
	"cold definition request was not replayed"
)
assert(not vim.lsp.is_enabled("basedpyright"), "TypeScript navigation initialized Python")
local function lazy_file(path)
	lifecycle.setup({ servers = servers, start_timeout_ms = 2000 })
	assert(vim.wait(3000, function()
		return #vim.lsp.get_clients() == 0
	end))
	if api.nvim_buf_get_name(0) ~= path then
		vim.cmd("hide edit " .. vim.fn.fnameescape(path))
	end
	api.nvim_win_set_cursor(0, { 2, 0 })
end
for _, key in ipairs({ "gri", "grt", "gD" }) do
	lazy_file(root .. "/source.py")
	api.nvim_feedkeys(key, "xt", false)
	assert(vim.lsp.is_enabled("basedpyright"), key .. " did not initialize Python")
	assert(
		vim.wait(3000, function()
			return api.nvim_win_get_cursor(0)[1] == 1
		end),
		key .. " was not replayed"
	)
end
lazy_file(root .. "/source.py")
api.nvim_feedkeys("grr", "xt", false)
assert(
	vim.wait(3000, function()
		return vim.bo.buftype == "quickfix"
	end),
	"cold references alias did not open its location list"
)
vim.cmd.lclose()

lazy_file(root .. "/source.ts")
api.nvim_feedkeys("gd", "xt", false)
api.nvim_win_set_cursor(0, { 2, 2 })
vim.wait(400)
assert(vim.deep_equal(api.nvim_win_get_cursor(0), { 2, 2 }), "stale cold navigation jumped after cursor movement")
lazy_file(root .. "/source.ts")
api.nvim_feedkeys("gd", "xt", false)
api.nvim_buf_set_lines(0, 0, 1, false, { "const value = 42;" })
vim.wait(400)
assert(api.nvim_win_get_cursor(0)[1] == 2, "stale cold navigation jumped after an edit")

lazy_file(root .. "/source.ts")
api.nvim_feedkeys("gd", "xt", false)
api.nvim_feedkeys(" lo", "xt", false)
api.nvim_buf_delete(api.nvim_get_current_buf(), { force = true })
vim.wait(500)
assert(#vim.lsp.get_clients() == 0, "manual off leaked a server whose source buffer closed during initialization")

lifecycle.setup({ servers = servers, start_timeout_ms = 60 })
vim.cmd("hide edit " .. vim.fn.fnameescape(root .. "/source.py"))
api.nvim_win_set_cursor(0, { 2, 0 })
api.nvim_feedkeys("gd", "xt", false)
vim.wait(400)
assert(api.nvim_win_get_cursor(0)[1] == 2, "a timed-out cold action was replayed")
assert(
	api.nvim_exec2("messages", { output = true }).output:find("Timed out waiting for LSP support", 1, true),
	"startup timeout was hidden"
)
local unsupported_ran = false
lifecycle.request("textDocument/prepareRename", function()
	unsupported_ran = true
end)
vim.wait(150)
assert(not unsupported_ran, "cold dispatch ignored server capabilities")

vim.lsp.enable(servers, false)
assert(vim.wait(3000, function()
	return #vim.lsp.get_clients() == 0
end))
vim.lsp.config("basedpyright", {
	cmd = { vim.fn.exepath("python3"), config .. "/tests/fixtures/idle_lsp.py", "fail" },
})
lifecycle.setup({ servers = servers, start_timeout_ms = 1000 })
api.nvim_feedkeys("gd", "xt", false)
assert(
	vim.wait(3000, function()
		return api.nvim_exec2("messages", { output = true }).output:find("quit with exit code 7", 1, true)
	end),
	"failed startup was not reported"
)
assert(api.nvim_win_get_cursor(0)[1] == 2, "a failed server executed a queued action")
assert(#vim.lsp.get_clients() == 0, "a failed startup leaked a server")
vim.lsp.config("basedpyright", {
	cmd = { vim.fn.exepath("python3"), config .. "/tests/fixtures/idle_lsp.py" },
})
api.nvim_feedkeys("gd", "xt", false)
assert(
	vim.wait(1000, function()
		return api.nvim_win_get_cursor(0)[1] == 1
	end),
	"semantic use could not retry a failed startup"
)
vim.lsp.enable(servers, false)
assert(vim.wait(3000, function()
	return #vim.lsp.get_clients() == 0
end))
vim.fn.delete(root, "rf")
print("lsp_first_use_spec: ok")
