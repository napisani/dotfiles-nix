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

local function assert_missing_mapping(entries, lhs)
	assert(not map_index(entries)[lhs], string.format("did not expect mapping %s", lhs))
end

local function assert_rhs(entry, rhs)
	assert(entry[2] == rhs, string.format("expected %s to map to %s, got %s", entry[1], rhs, tostring(entry[2])))
end

local function with_stubbed_vantage(module, callback)
	local original_loaded = package.loaded.vantage
	local original_preload = package.preload.vantage
	local captured_config = nil

	package.loaded.vantage = nil
	package.preload.vantage = function()
		return {
			setup = function(config)
				captured_config = config
			end,
		}
	end

	local ok, result = xpcall(function()
		module.setup()
		return callback(captured_config)
	end, debug.traceback)

	package.loaded.vantage = original_loaded
	package.preload.vantage = original_preload

	if not ok then
		error(result, 0)
	end

	return result
end

local function with_stubbed_lens(module, callback)
	local original_loaded = package.loaded.vantage
	local original_preload = package.preload.vantage
	local original_input = vim.ui.input
	local captured_lens = nil
	local input_calls = {}
	local responses = { "prefer small focused explanations" }

	package.loaded.vantage = nil
	package.preload.vantage = function()
		return {
			set_lens = function(mode, text)
				captured_lens = { mode = mode, text = text }
			end,
		}
	end

	vim.ui.input = function(opts, on_confirm)
		table.insert(input_calls, opts)
		on_confirm(table.remove(responses, 1))
	end

	local ok, result = xpcall(function()
		module.set_lens()
		return callback(captured_lens, input_calls)
	end, debug.traceback)

	package.loaded.vantage = original_loaded
	package.preload.vantage = original_preload
	vim.ui.input = original_input

	if not ok then
		error(result, 0)
	end

	return result
end

local spec_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local nvim_root = vim.fs.dirname(vim.fs.dirname(spec_path))
local lazy_source_path = vim.fs.joinpath(nvim_root, "lua", "user", "lazy.lua")

local vantage = require("user.plugins.ai.vantage")
local wiremux = require("user.plugins.ai.wiremux")
local registry = require("user.plugin_registry")

local keymaps = vantage.get_keymaps()
local wiremux_keymaps = wiremux.get_keymaps()

assert_has_mapping(keymaps.shared, "<leader>v")
assert_rhs(assert_has_mapping(keymaps.normal, "<leader>va"), "<cmd>VantageAnnotate<cr>")
assert_rhs(assert_has_mapping(keymaps.normal, "<leader>vA"), "<cmd>VantageAnnotate visible<cr>")
assert_rhs(assert_has_mapping(keymaps.normal, "<leader>vx"), "<cmd>VantageAnnotationClear<cr>")
assert(type(assert_has_mapping(keymaps.normal, "<leader>vl")[2]) == "function", "expected <leader>vl to set lens")
assert_rhs(assert_has_mapping(keymaps.normal, "<leader>v?"), "<cmd>VantageExplain<cr>")
assert_rhs(assert_has_mapping(keymaps.visual, "<leader>va"), ":VantageAnnotate<cr>")
assert_rhs(assert_has_mapping(keymaps.visual, "<leader>v?"), ":VantageExplain<cr>")

with_stubbed_lens(vantage, function(lens, input_calls)
	assert(#input_calls == 1, "expected one lens input dialog")
	assert(input_calls[1].prompt == "Lens: ", "expected lens text prompt")
	assert(lens.mode == "learning", "expected fixed learning lens mode")
	assert(lens.text == "prefer small focused explanations", "expected lens text from prompt")
end)

with_stubbed_vantage(vantage, function(config)
	assert(config.provider.name == "pi", "expected Vantage provider to be pi")
	assert(config.provider.pi.provider == "openai", "expected Pi to use the OpenAI backend")
	assert(config.provider.pi.model == "gpt-4o-mini", "expected Pi to use gpt-4o-mini")
end)

do
	local has_vantage_module = false
	for _, module in ipairs(registry.get_all_modules()) do
		if module == "ai.vantage" then
			has_vantage_module = true
			break
		end
	end
	assert(has_vantage_module, "expected ai.vantage in plugin registry")
end

do
	local lazy_source = table.concat(vim.fn.readfile(lazy_source_path), "\n")
	assert(lazy_source:match('dir = "/Users/nick/code/learn%-lsp"'), "expected local Vantage plugin dir")
	assert(lazy_source:match('name = "vantage%.nvim"'), "expected lazy name override")
	assert(lazy_source:match('build = "npm run compile"'), "expected local Vantage compile build")
end

assert_has_mapping(wiremux_keymaps.normal, "<leader>av")
assert_has_mapping(wiremux_keymaps.visual, "<leader>av")
assert_missing_mapping(wiremux_keymaps.normal, "<leader>v")
assert_missing_mapping(wiremux_keymaps.visual, "<leader>v")

print("vantage_keymaps_spec: ok")
