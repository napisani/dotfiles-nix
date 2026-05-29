local function map_index(entries)
	local index = {}
	for _, entry in ipairs(entries or {}) do
		index[entry[1]] = entry
	end
	return index
end

local function assert_has_mapping(entries, lhs)
	local entry = map_index(entries)[lhs]
	assert(entry, string.format("expected mapping %s", lhs))
	return entry
end

local function assert_buffer_filter(call, bufnr, context)
	assert(call.filter.bufnr == bufnr, context .. " should target the attached buffer")
	assert(call.filter.client_id == nil, context .. " should not pass client_id with bufnr")
end

local function with_inline_completion_stub(callback)
	local original_inline = vim.lsp.inline_completion
	local original_get_clients = vim.lsp.get_clients
	local original_notify = vim.notify
	local original_enabled = vim.g.user_copilot_inline_completion_enabled
	local calls = {}

	vim.lsp.inline_completion = {
		enable = function(enabled, filter)
			table.insert(calls, {
				enabled = enabled,
				filter = filter,
			})
		end,
	}
	vim.lsp.get_clients = function(filter)
		assert(filter.name == "copilot", "expected copilot client filter")
		return {
			{
				id = 42,
				name = "copilot",
				attached_buffers = {
					[7] = true,
					[9] = true,
				},
			},
		}
	end
	vim.notify = function() end
	vim.g.user_copilot_inline_completion_enabled = nil

	local ok, err = pcall(function()
		callback(calls)
	end)

	vim.lsp.inline_completion = original_inline
	vim.lsp.get_clients = original_get_clients
	vim.notify = original_notify
	vim.g.user_copilot_inline_completion_enabled = original_enabled

	assert(ok, err)
end

local copilot = require("user.plugins.ai.copilot")
local keymaps = copilot.get_keymaps()

local toggle = assert_has_mapping(keymaps.normal, "<leader>lC")
assert(type(toggle[2]) == "function", "expected <leader>lC to call a toggle function")
assert(toggle.desc == "toggle copilot inline completion", "expected clear copilot toggle description")

with_inline_completion_stub(function(calls)
	assert(copilot.is_enabled(), "expected copilot inline completion to default enabled")

	copilot.toggle_inline_completion()
	assert(vim.g.user_copilot_inline_completion_enabled == false, "expected toggle to disable copilot")
	assert(#calls == 2, "expected disable call for each attached copilot buffer")
	assert(calls[1].enabled == false, "expected first call to disable inline completion")
	assert_buffer_filter(calls[1], 7, "expected first call")
	assert(calls[2].enabled == false, "expected second call to disable inline completion")
	assert_buffer_filter(calls[2], 9, "expected second call")

	copilot.toggle_inline_completion()
	assert(vim.g.user_copilot_inline_completion_enabled == true, "expected second toggle to enable copilot")
	assert(#calls == 4, "expected enable call for each attached copilot buffer")
	assert(calls[3].enabled == true, "expected third call to enable inline completion")
	assert(calls[4].enabled == true, "expected fourth call to enable inline completion")
end)

with_inline_completion_stub(function(calls)
	vim.g.user_copilot_inline_completion_enabled = false

	local enabled = copilot.enable_for_client({ id = 44, name = "copilot" }, 11)
	assert(enabled == false, "expected disabled preference to suppress LspAttach enable")
	assert(#calls == 0, "expected no inline enable call while copilot is disabled")

	vim.g.user_copilot_inline_completion_enabled = true
	enabled = copilot.enable_for_client({ id = 44, name = "copilot" }, 11)
	assert(enabled == true, "expected enabled preference to allow LspAttach enable")
	assert(#calls == 1, "expected one inline enable call")
	assert(calls[1].enabled == true, "expected LspAttach helper to enable inline completion")
	assert_buffer_filter(calls[1], 11, "expected LspAttach helper")
end)

print("copilot_keymap_spec: ok")
