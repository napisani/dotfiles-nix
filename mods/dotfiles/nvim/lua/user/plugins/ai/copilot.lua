-- Copilot inline completion setup using native vim.lsp.inline_completion (Neovim 0.12+)
-- Requires: copilot-language-server installed via mason, vim.lsp.enable("copilot") in lsp/init.lua
--
-- Tab accepts the current inline suggestion; when no suggestion is visible,
-- Tab falls through to blink.cmp's snippet_forward or a literal tab.

local M = {}

local enabled_var = "user_copilot_inline_completion_enabled"

function M.is_enabled()
	return vim.g[enabled_var] ~= false
end

local function inline_completion()
	local inline = vim.lsp and vim.lsp.inline_completion or nil
	if not inline or type(inline.enable) ~= "function" then
		return nil
	end
	return inline
end

local function attached_copilot_buffers()
	local clients = vim.lsp.get_clients({ name = "copilot" })
	local buffers = {}
	for _, client in ipairs(clients) do
		for bufnr, attached in pairs(client.attached_buffers or {}) do
			if attached then
				table.insert(buffers, {
					client_id = client.id,
					bufnr = bufnr,
				})
			end
		end
	end
	table.sort(buffers, function(left, right)
		if left.client_id == right.client_id then
			return left.bufnr < right.bufnr
		end
		return left.client_id < right.client_id
	end)
	return buffers
end

function M.set_inline_completion_enabled(enabled, opts)
	enabled = enabled and true or false
	vim.g[enabled_var] = enabled

	local inline = inline_completion()
	if not inline then
		vim.notify("copilot: native inline completion is unavailable", vim.log.levels.WARN)
		return enabled
	end

	for _, target in ipairs(attached_copilot_buffers()) do
		inline.enable(enabled, {
			client_id = target.client_id,
			bufnr = target.bufnr,
		})
	end

	if not opts or opts.notify ~= false then
		local state = enabled and "enabled" or "disabled"
		vim.notify("copilot inline completion " .. state, vim.log.levels.INFO)
	end

	return enabled
end

function M.toggle_inline_completion()
	return M.set_inline_completion_enabled(not M.is_enabled())
end

function M.enable_for_client(client, bufnr)
	if not M.is_enabled() then
		return false
	end

	local inline = inline_completion()
	if not inline then
		return false
	end

	inline.enable(true, {
		client_id = client.id,
		bufnr = bufnr,
	})
	return true
end

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
		normal = {
			{ "<leader>lC", M.toggle_inline_completion, desc = "toggle copilot inline completion" },
		},
		shared = {
			{ "<Tab>", group = "copilot inline completion (insert)" },
		},
	}
end

return M
