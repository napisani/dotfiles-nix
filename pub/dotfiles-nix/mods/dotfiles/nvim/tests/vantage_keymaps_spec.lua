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
		module.configure(module.opts)
		return callback(captured_config)
	end, debug.traceback)

	package.loaded.vantage = original_loaded
	package.preload.vantage = original_preload

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
assert_rhs(assert_has_mapping(keymaps.normal, "<leader>vl"), "<cmd>VantageSetLens learning<cr>")
assert_rhs(assert_has_mapping(keymaps.normal, "<leader>ve"), "<cmd>VantageEdit<cr>")
assert_missing_mapping(keymaps.normal, "<leader>vE")
assert_rhs(assert_has_mapping(keymaps.normal, "<leader>v?"), "<cmd>VantageQuestion<cr>")
assert_rhs(assert_has_mapping(keymaps.visual, "<leader>va"), ":VantageAnnotate<cr>")
assert_rhs(assert_has_mapping(keymaps.visual, "<leader>ve"), ":VantageEdit<cr>")
assert_missing_mapping(keymaps.visual, "<leader>vE")
assert_rhs(assert_has_mapping(keymaps.visual, "<leader>v?"), ":VantageQuestion<cr>")

with_stubbed_vantage(vantage, function(config)
	assert(config.provider == nil, "expected no legacy Vantage provider adapter config")
	assert(config.agent.provider == "openai-codex", "expected Pi to use the OpenAI Codex subscription provider")
	assert(config.ui == nil, "expected Vantage to use the plugin default UI config")
	assert(config.agent.model == "gpt-5.4-mini", "expected Pi to use the configured Codex model")
	assert(config.agent.auth == nil, "expected Vantage to use its default Pi OAuth auth path lookup")
	assert(config.agent.options.reasoning == "minimal", "expected configured Codex reasoning")
	assert((config.agent.options or {}).apiKey == nil, "expected credentials to be delegated to Pi")
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
