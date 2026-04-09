-- Copilot inline completion setup using native vim.lsp.inline_completion (Neovim 0.12+)
-- Requires: copilot-language-server installed via mason, vim.lsp.enable("copilot") in lsp/init.lua
--
-- Tab accepts the current inline suggestion; when no suggestion is visible,
-- Tab falls through to blink.cmp's snippet_forward or a literal tab.

local M = {}

function M.setup()
	-- Set <Tab> in insert mode to accept the current copilot inline completion.
	-- vim.lsp.inline_completion.get() returns true when a suggestion was accepted,
	-- so we can fall back gracefully when nothing is shown.
	vim.keymap.set("i", "<Tab>", function()
		if vim.lsp.inline_completion.get() then
			-- accepted — return nothing (get() schedules the insertion)
			return ""
		end
		-- fallback: let blink.cmp / snippet handle Tab
		return "<Tab>"
	end, {
		expr = true,
		noremap = true,
		silent = true,
		replace_keycodes = false,
		desc = "copilot: accept inline completion or fallback",
	})
end

function M.get_keymaps()
	return {
		normal = {},
		shared = {
			{ "<Tab>", group = "copilot inline completion (insert)" },
		},
	}
end

return M
