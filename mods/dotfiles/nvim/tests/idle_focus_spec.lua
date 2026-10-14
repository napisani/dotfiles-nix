local api = vim.api
local config = vim.fn.getcwd() .. "/pub/dotfiles-nix/mods/dotfiles/nvim"
vim.opt.rtp:prepend(config)
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.fn.writefile({
	"#!/bin/sh",
	'sleep "${IDLE_TMUX_DELAY:-0}"',
	'printf "%s\\n" "$IDLE_TMUX_CLIENTS"',
	'exit "${IDLE_TMUX_EXIT:-0}"',
}, root .. "/tmux")
vim.fn.setfperm(root .. "/tmux", "rwx------")
vim.env.PATH = root .. ":" .. vim.env.PATH
vim.env.TMUX = "fixture"
vim.env.TMUX_PANE = "%12345"
vim.env.IDLE_TMUX_CLIENTS = "%98765 attached,focused,UTF-8"
vim.lsp.config("vtsls", { cmd = { "unused" }, filetypes = { "typescript" } })
require("user.lsp.lifecycle").setup({ servers = { "vtsls" } })
vim.cmd.LspEnable()
local idle = require("user.idle")
idle.setup({ timeout_ms = 50 })
api.nvim_exec_autocmds("UIEnter", {})
assert(
	vim.wait(3000, function()
		return not vim.lsp.is_enabled("vtsls")
	end),
	"an editor opened in a background tmux session never went idle"
)

api.nvim_exec_autocmds("FocusGained", {})
assert(vim.lsp.is_enabled("vtsls"))
vim.env.IDLE_TMUX_CLIENTS = "%98765 attached,focused,UTF-8\n%12345 attached,focused,UTF-8"
api.nvim_exec_autocmds("UIEnter", {})
vim.wait(150)
assert(vim.lsp.is_enabled("vtsls"), "another focused tmux client was ignored")

vim.env.IDLE_TMUX_CLIENTS = "%98765 attached,focused,UTF-8"
vim.env.IDLE_TMUX_DELAY = "0.1"
api.nvim_exec_autocmds("UIEnter", {})
api.nvim_exec_autocmds("FocusGained", {})
vim.wait(250)
assert(vim.lsp.is_enabled("vtsls"), "a stale tmux query overrode a newer focus event")

api.nvim_exec_autocmds("FocusLost", {})
idle.setup({ timeout_ms = 50 })
assert(
	vim.wait(3000, function()
		return not vim.lsp.is_enabled("vtsls")
	end),
	"reconfiguring an inactive editor lost its idle timer"
)
api.nvim_exec_autocmds("FocusGained", {})
vim.env.IDLE_TMUX_DELAY = "0"
vim.env.IDLE_TMUX_CLIENTS = "unexpected output"
api.nvim_exec_autocmds("UIEnter", {})
vim.wait(150)
assert(vim.lsp.is_enabled("vtsls"), "invalid tmux output put an active editor to sleep")
assert(
	api.nvim_exec2("IdleStatus", { output = true }).output:find("focus_probe_error", 1, true),
	"focus detection failure was hidden"
)

vim.env.IDLE_TMUX_EXIT = "1"
api.nvim_exec_autocmds("UIEnter", {})
vim.wait(150)
assert(vim.lsp.is_enabled("vtsls"), "a failed tmux query put an active editor to sleep")
api.nvim_exec_autocmds("UILeave", {})
assert(
	vim.wait(3000, function()
		return not vim.lsp.is_enabled("vtsls")
	end),
	"an editor without a UI never went idle"
)
vim.fn.delete(root, "rf")
print("idle_focus_spec: ok")
