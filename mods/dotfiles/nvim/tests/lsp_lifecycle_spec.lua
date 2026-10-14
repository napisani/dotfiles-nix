local api = vim.api
local config = vim.fn.getcwd() .. "/pub/dotfiles-nix/mods/dotfiles/nvim"
vim.opt.rtp:prepend(config)
vim.g.mapleader = " "
vim.env.TMUX = nil
vim.env.TMUX_PANE = nil
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
root = assert(vim.uv.fs_realpath(root))
vim.fn.writefile({ "const value = 1;", "value;" }, root .. "/source.ts")
vim.fn.writefile({ "value = 1", "value" }, root .. "/source.py")
local servers = { "vtsls", "basedpyright", "ruff", "idle_light" }
for _, name in ipairs(servers) do
	vim.lsp.config(name, {
		cmd = { vim.fn.exepath("python3"), config .. "/tests/fixtures/idle_lsp.py" },
		filetypes = name == "vtsls" and { "typescript" } or name == "idle_light" and { "typescript", "python" } or {
			"python",
		},
		root_dir = root,
		exit_timeout = 100,
	})
end
vim.lsp.enable(servers)
require("user.lsp.attach").setup()
local lifecycle = require("user.lsp.lifecycle")
lifecycle.setup({ servers = servers })
assert(not vim.lsp.is_enabled("vtsls"), "lazy startup enabled TypeScript")
assert(not vim.lsp.is_enabled("basedpyright"), "lazy startup enabled Python type analysis")
assert(not vim.lsp.is_enabled("ruff"), "lazy startup enabled the deferred Python companion")
assert(vim.lsp.is_enabled("idle_light"), "lazy startup disabled a lightweight server")
vim.cmd.edit(root .. "/source.py")
vim.cmd.edit(root .. "/source.ts")
assert(vim.wait(3000, function()
	return #vim.lsp.get_clients({ name = "idle_light" }) == 1
end))
assert(#vim.lsp.get_clients({ name = "vtsls" }) == 0)
assert(#vim.lsp.get_clients({ name = "basedpyright" }) == 0)
local prompt = api.nvim_create_buf(false, true)
api.nvim_buf_set_name(prompt, root .. "/prompt.ts")
vim.bo[prompt].filetype = "typescript"
vim.b[prompt].vantage_prompt_buffer = true
api.nvim_set_current_buf(prompt)
api.nvim_exec_autocmds("InsertEnter", {})
assert(not vim.lsp.is_enabled("vtsls"), "prompt insertion initialized TypeScript")
vim.cmd.edit(root .. "/source.py")
api.nvim_exec_autocmds("InsertEnter", {})
assert(
	vim.wait(3000, function()
		return #vim.lsp.get_clients({ name = "basedpyright" }) == 1 and #vim.lsp.get_clients({ name = "ruff" }) == 1
	end),
	"Python insertion did not initialize the heavyweight Python servers"
)
assert(not vim.lsp.is_enabled("vtsls"), "Python insertion initialized TypeScript")
local python_client = vim.lsp.get_clients({ name = "basedpyright" })[1]
local completion = assert(python_client:request_sync("textDocument/completion", {
	textDocument = { uri = vim.uri_from_bufnr(0) },
	position = { line = 1, character = 2 },
}, 1000, 0)).result
assert(completion[1].label == "fixture_completion", "completion was not available after first-use activation")
lifecycle.setup({ servers = servers })
assert(vim.wait(3000, function()
	return #vim.lsp.get_clients({ name = "basedpyright" }) == 0
end))
vim.cmd.edit(root .. "/source.ts")
local buf = api.nvim_get_current_buf()
api.nvim_buf_set_lines(buf, 0, -1, false, { "const value = 2;", "value;" })
local tick = api.nvim_buf_get_changedtick(buf)
local undo = vim.fn.undotree().seq_cur
local function toggle()
	api.nvim_feedkeys(" lo", "xt", false)
end
toggle()
assert(
	vim.wait(3000, function()
		return #vim.lsp.get_clients() == 4
	end),
	"toggle on did not start all selected LSPs"
)
require("user.idle").setup({ timeout_ms = 40 })
api.nvim_exec_autocmds("FocusLost", {})
assert(
	vim.wait(3000, function()
		return #vim.lsp.get_clients({ name = "basedpyright" }) == 0 and #vim.lsp.get_clients({ name = "ruff" }) == 0
	end),
	"idle sleep left heavyweight Python servers running"
)
assert(#vim.lsp.get_clients({ name = "idle_light" }) == 1, "idle sleep stopped a lightweight server")
toggle()
assert(
	vim.wait(3000, function()
		return #vim.lsp.get_clients() == 0
	end),
	"toggle off left an LSP running"
)
api.nvim_exec_autocmds("InsertEnter", {})
api.nvim_exec_autocmds("FocusLost", {})
api.nvim_exec_autocmds("FocusGained", {})
for _, key in ipairs({ "gd", "gri", "grr", "grn", "gra", "K", "gO" }) do
	api.nvim_feedkeys(key, "xt", false)
end
api.nvim_feedkeys(api.nvim_replace_termcodes("i<C-s><Esc>", true, false, true), "xt", false)
vim.wait(150)
for _, name in ipairs(servers) do
	assert(not vim.lsp.is_enabled(name), "manual off was not sticky for " .. name)
end
assert(api.nvim_buf_get_changedtick(buf) == tick, "toggle rewrote unsaved text")
assert(vim.fn.undotree().seq_cur == undo, "toggle changed undo history")
assert(vim.bo[buf].modified)
toggle()
assert(
	vim.wait(3000, function()
		return #vim.lsp.get_clients() == 4
	end),
	"toggle did not restore language services"
)
vim.lsp.enable(servers, false)
assert(vim.wait(3000, function()
	return #vim.lsp.get_clients() == 0
end))
lifecycle.setup({ servers = servers })
assert(
	not vim.lsp.is_enabled("vtsls") and not vim.lsp.is_enabled("basedpyright"),
	"startup did not defer heavyweight servers"
)
api.nvim_exec_autocmds("FocusLost", {})
vim.wait(100)
api.nvim_exec_autocmds("FocusGained", {})
assert(
	not vim.lsp.is_enabled("vtsls") and not vim.lsp.is_enabled("basedpyright"),
	"focus activated servers never requested after startup"
)
vim.lsp.enable(servers, false)
assert(vim.wait(3000, function()
	return #vim.lsp.get_clients() == 0
end))
vim.fn.delete(root, "rf")
print("lsp_lifecycle_spec: ok")
