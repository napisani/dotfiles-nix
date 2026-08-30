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
assert(mapped.gi, "expected gi (go-to-implementation) to be mapped")

do
	local category = require("user.scope.category")
	category.reset_all()
	category.select_scope("tests")

	local original_references = vim.lsp.buf.references
	local captured_on_list
	vim.lsp.buf.references = function(_, opts)
		captured_on_list = opts.on_list
	end

	mapped.gr.action()
	assert(type(captured_on_list) == "function", "expected gr to pass an on_list callback")

	local original_setloclist = vim.fn.setloclist
	local original_lopen = vim.cmd.lopen
	local captured_items
	vim.fn.setloclist = function(_, _, _, list_ctx)
		captured_items = list_ctx.items
	end
	vim.cmd.lopen = function() end

	captured_on_list({
		items = {
			{ filename = "foo/bar.lua" },
			{ filename = "foo/bar_test.lua" },
		},
	})

	vim.fn.setloclist = original_setloclist
	vim.cmd.lopen = original_lopen
	vim.lsp.buf.references = original_references

	assert(#captured_items == 1, "expected on_list to filter out the non-selected-category location")
	assert(
		captured_items[1].filename == "foo/bar_test.lua",
		"expected the selected-category location to survive filtering"
	)

	category.reset_all()
end

print("lsp_attach_spec: ok")
