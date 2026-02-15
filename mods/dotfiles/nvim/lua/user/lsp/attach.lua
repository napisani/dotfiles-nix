local M = {}
local keymaps = require("user.lsp.keymaps")

local function load_server_keymaps(server_name)
	return keymaps.per_server[server_name] or {}
end

local function apply_keymap(client, bufnr, keymap, mode)
	mode = mode or "n"

	if keymap.method and not client.supports_method(keymap.method) then
		return
	end

	local opts = {
		buffer = bufnr,
		noremap = true,
		silent = true,
		desc = keymap.desc,
	}

	vim.keymap.set(mode, keymap.key, keymap.action, opts)
end

function M.on_attach(client, bufnr)
	for _, keymap in ipairs(keymaps.base) do
		apply_keymap(client, bufnr, keymap, "n")
	end

	for _, keymap in ipairs(keymaps.base_visual) do
		apply_keymap(client, bufnr, keymap, "v")
	end

	local server_keymaps = load_server_keymaps(client.name)
	for _, keymap in ipairs(server_keymaps) do
		apply_keymap(client, bufnr, keymap, keymap.mode or "n")
	end
end

function M.setup()
	vim.api.nvim_create_autocmd('LspAttach', {
		group = vim.api.nvim_create_augroup('UserLspConfig', { clear = true }),
		callback = function(ev)
			local client = vim.lsp.get_clients({ id = ev.data.client_id })[1]
			if client then
				M.on_attach(client, ev.buf)
			end
		end,
	})
end

return M
