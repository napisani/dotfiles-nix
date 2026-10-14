local api = vim.api
local config = vim.fn.getcwd() .. "/pub/dotfiles-nix/mods/dotfiles/nvim"
vim.opt.rtp:prepend(config)
for _, plugin in ipairs({ "lualine.nvim", "nvim-web-devicons" }) do
	vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end
vim.env.TMUX = nil
vim.env.TMUX_PANE = nil

require("user.plugins.ui.lualine").setup()
local lualine = require("lualine")
local initial = lualine.get_config().options.refresh
local label = "before background"
lualine.setup({ sections = { lualine_c = {
	function()
		return label
	end,
} } })
require("user.idle").setup()
assert(
	api.nvim_exec2("IdleStatus", { output = true }).output:find("timeout_ms = 900000", 1, true),
	"default sleep timeout is not 15 minutes"
)
api.nvim_exec_autocmds("FocusLost", {})
local background = lualine.get_config().options.refresh
assert(background.refresh_time >= 1000, "background statusline still polls at foreground speed")
assert(background.statusline >= 5000, "background statusline still redraws every second")
assert(vim.deep_equal(background.events, { "FocusGained" }), "background buffer activity still requests redraws")
vim.wait(100)
label = "after returning"
api.nvim_exec_autocmds("CursorMoved", {})
vim.wait(100)
local function rendered()
	return api.nvim_eval_statusline(vim.wo.statusline, { winid = api.nvim_get_current_win() }).str
end
assert(rendered():find("before background", 1, true), "background input refreshed the statusline")
api.nvim_exec_autocmds("FocusGained", {})
local restored = lualine.get_config().options.refresh
assert(restored.refresh_time == initial.refresh_time, "foreground responsiveness was not restored")
assert(vim.deep_equal(restored.events, initial.events), "foreground refresh events changed")
assert(rendered():find("after returning", 1, true), "focus did not immediately refresh the statusline")
print("idle_ui_spec: ok")
