local api = vim.api
local config = vim.fn.getcwd() .. "/pub/dotfiles-nix/mods/dotfiles/nvim"
vim.opt.rtp:prepend(config)
vim.env.TMUX = nil
vim.env.TMUX_PANE = nil

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
root = assert(vim.uv.fs_realpath(root))
vim.fn.writefile({ "const saved = true;" }, root .. "/one.ts")
vim.lsp.config("vtsls", {
	cmd = { vim.fn.exepath("python3"), config .. "/tests/fixtures/idle_lsp.py" },
	filetypes = { "typescript" },
	root_dir = root,
})
vim.lsp.config("idle_other", {
	cmd = { vim.fn.exepath("python3"), config .. "/tests/fixtures/idle_lsp.py" },
	filetypes = { "typescript" },
	root_dir = root,
	exit_timeout = 1000,
})
require("user.lsp.lifecycle").setup({ servers = { "vtsls", "idle_other" } })
vim.cmd.LspEnable()
assert(vim.lsp.config.vtsls.exit_timeout == 1000, "TypeScript shutdown has no bounded grace period")
vim.cmd.edit(root .. "/one.ts")
assert(
	vim.wait(3000, function()
		return #vim.lsp.get_clients({ name = "vtsls", bufnr = 0 }) == 1
			and #vim.lsp.get_clients({ name = "idle_other", bufnr = 0 }) == 1
	end),
	"fixture LSP failed to attach"
)
local original_client = vim.lsp.get_clients({ name = "vtsls" })[1]
local other_client = vim.lsp.get_clients({ name = "idle_other" })[1]
local buf = api.nvim_get_current_buf()
local unsaved = { "const saved = false;", "// unsaved work" }
api.nvim_buf_set_lines(buf, 0, -1, false, unsaved)
local changedtick = api.nvim_buf_get_changedtick(buf)
local undo_sequence = vim.fn.undotree().seq_cur
local view = vim.fn.winsaveview()
local layout = vim.fn.winlayout()

require("user.idle").setup({ timeout_ms = 50 })
api.nvim_exec_autocmds("FocusLost", {})
assert(
	vim.wait(3000, function()
		return #vim.lsp.get_clients({ id = original_client.id }) == 0
	end),
	"inactive TypeScript server did not exit"
)
assert(not vim.lsp.is_enabled("vtsls"), "background file opens must not restart TypeScript")
assert(#vim.lsp.get_clients({ id = other_client.id }) == 1, "idle policy stopped an unrelated language server")
local background_buf = api.nvim_create_buf(true, false)
api.nvim_buf_set_name(background_buf, root .. "/two.ts")
api.nvim_buf_call(background_buf, function()
	vim.bo.filetype = "typescript"
end)
vim.wait(100)
assert(#vim.lsp.get_clients({ name = "vtsls" }) == 0, "background TypeScript file restarted the sleeping server")

api.nvim_exec_autocmds("FocusGained", {})
assert(
	vim.wait(3000, function()
		local clients = vim.lsp.get_clients({ name = "vtsls", bufnr = buf })
		return #clients == 1 and clients[1].id ~= original_client.id
	end),
	"returning to the editor did not restart TypeScript"
)
local resumed = vim.lsp.get_clients({ name = "vtsls", bufnr = buf })[1]
assert(api.nvim_get_current_buf() == buf, "resume switched buffers")
assert(vim.deep_equal(api.nvim_buf_get_lines(buf, 0, -1, false), unsaved), "unsaved text changed")
assert(vim.bo[buf].modified, "unsaved buffer was marked saved")
assert(api.nvim_buf_get_changedtick(buf) == changedtick, "resume rewrote the buffer")
assert(vim.fn.undotree().seq_cur == undo_sequence, "resume changed undo history")
assert(vim.deep_equal(vim.fn.winsaveview(), view), "resume changed the editing view")
assert(vim.deep_equal(vim.fn.winlayout(), layout), "resume changed the window layout")
assert(
	vim.wait(3000, function()
		return #vim.lsp.get_clients({ name = "vtsls", bufnr = background_buf }) == 1
	end),
	"resume did not attach to a buffer opened while asleep"
)
local state = assert(resumed:request_sync("test/state", {}, 1000, buf)).result
assert(
	state.documents[vim.uri_from_bufnr(buf)] == table.concat(unsaved, "\n") .. "\n",
	"LSP resumed from disk instead of unsaved text"
)

api.nvim_exec_autocmds("FocusLost", {})
vim.wait(15)
api.nvim_exec_autocmds("FocusGained", {})
vim.wait(100)
assert(
	vim.lsp.get_clients({ name = "vtsls", bufnr = buf })[1].id == resumed.id,
	"brief pane switching restarted TypeScript"
)

vim.lsp.enable("vtsls", false)
assert(vim.wait(3000, function()
	return #vim.lsp.get_clients({ name = "vtsls" }) == 0
end))
api.nvim_exec_autocmds("FocusLost", {})
vim.wait(100)
api.nvim_exec_autocmds("FocusGained", {})
assert(not vim.lsp.is_enabled("vtsls"), "focus enabled an intentionally disabled server")

vim.lsp.config("vtsls", {
	cmd = { vim.fn.exepath("python3"), config .. "/tests/fixtures/idle_lsp.py", "hang", "0.2" },
})
vim.lsp.enable("vtsls")
assert(vim.wait(3000, function()
	return #vim.lsp.get_clients({ name = "vtsls" }) == 1
end))
api.nvim_exec_autocmds("FocusLost", {})
assert(
	vim.wait(3000, function()
		return #vim.lsp.get_clients({ name = "vtsls" }) == 0
	end),
	"a server ignoring shutdown was never terminated"
)
local responsive = false
vim.defer_fn(function()
	responsive = true
end, 10)
api.nvim_exec_autocmds("FocusGained", {})
assert(not responsive, "resuming blocked inside the language-server handshake")
assert(
	vim.wait(100, function()
		return responsive
	end),
	"the editor did not respond while restarting TypeScript"
)
assert(#vim.lsp.get_clients({ name = "vtsls" }) == 0, "fixture initialized before the responsiveness check")
assert(vim.wait(3000, function()
	return #vim.lsp.get_clients({ name = "vtsls" }) == 1
end))

local retiring = vim.lsp.get_clients({ name = "vtsls" })[1]
api.nvim_exec_autocmds("FocusLost", {})
assert(vim.wait(1000, function()
	return not vim.lsp.is_enabled("vtsls")
end))
assert(#vim.lsp.get_clients({ id = retiring.id }) == 1, "fixture exited before testing an overlapping resume")
api.nvim_exec_autocmds("FocusGained", {})
assert(
	vim.wait(3000, function()
		local clients = vim.lsp.get_clients({ name = "vtsls" })
		return #clients == 1 and clients[1].id ~= retiring.id and not clients[1]:is_stopped()
	end),
	"returning during shutdown reused a retiring client"
)

vim.lsp.enable({ "vtsls", "idle_other" }, false)
assert(vim.wait(3000, function()
	return #vim.lsp.get_clients() == 0
end))
vim.fn.delete(root, "rf")
print("idle_spec: ok")
