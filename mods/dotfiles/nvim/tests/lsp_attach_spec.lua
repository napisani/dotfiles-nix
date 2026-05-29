local attach = require("user.lsp.attach")

local original_keymap_set = vim.keymap.set
local set_calls = {}
vim.keymap.set = function(mode, key, action, opts)
	table.insert(set_calls, {
		mode = mode,
		key = key,
		action = action,
		opts = opts,
	})
end

local client = {
	name = "unit-test-lsp",
}
local support_calls = {}

function client:supports_method(method, bufnr)
	assert(self == client, "expected supports_method to be called with colon syntax")
	assert(type(method) == "string", "expected supports_method method name")
	assert(bufnr == 13, "expected supports_method to receive the attached buffer")
	table.insert(support_calls, method)
	return method ~= "textDocument/formatting"
end

local ok, err = pcall(function()
	attach.on_attach(client, 13)
end)

vim.keymap.set = original_keymap_set

assert(ok, err)
assert(#support_calls > 0, "expected capability-gated keymaps to check client support")

local mapped = {}
for _, call in ipairs(set_calls) do
	mapped[call.key] = call
	assert(call.opts.buffer == 13, "expected attached LSP keymaps to be buffer-local")
end

assert(mapped.gd, "expected supported definition keymap")
assert(not mapped["<leader>lf"], "expected unsupported formatting keymap to be skipped")

print("lsp_attach_spec: ok")
