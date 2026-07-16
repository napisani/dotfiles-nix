local function map_index(entries)
	local index = {}
	for _, entry in ipairs(entries or {}) do
		index[entry[1]] = entry
	end
	return index
end

local function assert_has_mapping(entries, lhs)
	assert(map_index(entries)[lhs], string.format("expected mapping %s", lhs))
end

local function assert_missing_mapping(entries, lhs)
	assert(not map_index(entries)[lhs], string.format("did not expect mapping %s", lhs))
end

local function with_temporary_value(tbl, key, value, callback)
	local original = tbl[key]
	tbl[key] = value

	local ok, result = xpcall(callback, debug.traceback)
	tbl[key] = original

	if not ok then
		error(result, 0)
	end

	return result
end

local function with_temporary_cwd(path, callback)
	local original = vim.fn.getcwd()
	vim.cmd("cd " .. vim.fn.fnameescape(path))

	local ok, result = xpcall(callback, debug.traceback)
	vim.cmd("cd " .. vim.fn.fnameescape(original))

	if not ok then
		error(result, 0)
	end

	return result
end

local spec_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local nvim_root = vim.fs.dirname(vim.fs.dirname(spec_path))
local ai_actions_source_path = vim.fs.joinpath(nvim_root, "lua", "user", "snacks", "ai_actions.lua")

local wiremux = require("user.plugins.ai.wiremux")
local wiremux_actions = require("user.snacks.ai_actions.wiremux")
local ai_action_common = require("user.snacks.ai_actions.common")
local ai_actions = require("user.snacks.ai_actions")
local ai_skills = require("user.snacks.ai_skills")
local skill_source = require("user.completion.sources.skills")
local keymaps = wiremux.get_keymaps()
local route_definitions = wiremux.get_route_definitions()

assert(type(ai_actions.append_snack_context_to_prompt_builder) == "function")
assert(type(ai_actions.append_memo_to_prompt_builder) == "function")
assert(type(ai_actions.stage_context) == "function")

do
	local source = vim.fn.readfile(ai_actions_source_path)
	local joined = table.concat(source, "\n")
	assert(not joined:match("codecompanion"), "ai_actions.lua should not reference codecompanion")
	assert(not joined:match("agentic"), "ai_actions.lua should not reference agentic")
end

-- Regression: wiremux keymap surface (see BEHAVIOR.md <leader>a)
assert_has_mapping(keymaps.normal, "<leader>af")
assert_has_mapping(keymaps.normal, "<leader>aff")
assert_has_mapping(keymaps.normal, "<leader>afe")
assert_has_mapping(keymaps.normal, "<leader>afr")
assert_has_mapping(keymaps.normal, "<leader>aft")
assert_has_mapping(keymaps.normal, "<leader>afd")
assert_has_mapping(keymaps.normal, "<leader>afD")
assert_has_mapping(keymaps.normal, "<leader>afC")
assert_has_mapping(keymaps.normal, "<leader>av")
assert_has_mapping(keymaps.normal, "<leader>ai")
assert_has_mapping(keymaps.normal, "<leader>ao")
assert_has_mapping(keymaps.normal, "<leader>a?")
assert_has_mapping(keymaps.normal, "<leader>ap")
assert_has_mapping(keymaps.normal, "<leader>am")
assert_has_mapping(keymaps.normal, "<leader>aw")
assert_has_mapping(keymaps.normal, "<leader>aq")
assert_has_mapping(keymaps.normal, "<leader>ae")
assert_has_mapping(keymaps.visual, "<leader>ai")
assert_has_mapping(keymaps.visual, "<leader>aff")
assert_has_mapping(keymaps.visual, "<leader>av")
assert_has_mapping(keymaps.visual, "<leader>am")
assert_has_mapping(keymaps.visual, "<leader>ae")
assert_has_mapping(keymaps.visual, "<leader>a?")

assert_missing_mapping(keymaps.normal, "<leader>Ao")
assert_missing_mapping(keymaps.normal, "<leader>A?")
assert_missing_mapping(keymaps.normal, "<leader>AP")
assert_missing_mapping(keymaps.normal, "<leader>AS")
assert_missing_mapping(keymaps.visual, "<leader>Ao")

assert(route_definitions.pi, "expected pi route definition")
assert(route_definitions.pi.label == "Pi", "expected Pi route label")
assert(route_definitions.pi.cmd == "pi", "expected Pi route command")

assert(ai_skills.skill_invocation("example", { provider = "opencode" }) == "/skill example")
assert(ai_skills.skill_invocation("example", { provider = "claude" }) == "/example")
assert(ai_skills.skill_invocation("example", { provider = "codex" }) == "$example")
assert(ai_skills.skill_invocation("example", { provider = "pi" }) == "/skill:example")

do
	local function completion_for(provider, line)
		local b = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_var(b, "prompt_builder", true)
		vim.api.nvim_buf_set_lines(b, 0, -1, false, { line })

		local result
		with_temporary_value(wiremux, "get_current_route", function()
			return provider
		end, function()
			with_temporary_value(ai_skills, "list", function()
				return {
					{
						name = "test-skill",
						description = "Test skill",
						path = "/tmp/test-skill/SKILL.md",
					},
				}
			end, function()
				skill_source.new({}):get_completions({
					bufnr = b,
					line = line,
					cursor = { line = 0, character = #line },
				}, function(payload)
					result = payload
				end)
			end)
		end)

		vim.api.nvim_buf_delete(b, { force = true })
		return result
	end

	assert(skill_source.new({}):get_trigger_characters()[1] == "$")
	assert(completion_for("opencode", "$").items[1].textEdit.newText == "/skill test-skill")
	assert(completion_for("claude", "$").items[1].textEdit.newText == "/test-skill")
	local claude_completion = completion_for("claude", "$test").items[1]
	assert(claude_completion.textEdit.newText == "/test-skill")
	assert(claude_completion.filterText:match("%$test%-skill"))
	assert(claude_completion.textEdit.range.start.character == 0)
	assert(claude_completion.textEdit.range["end"].character == #"$test")
	assert(completion_for("codex", "$").items[1].textEdit.newText == "$test-skill")
	assert(completion_for("pi", "$").items[1].textEdit.newText == "/skill:test-skill")
	assert(#completion_for("opencode", "/").items == 0)
	assert(#completion_for("claude", "/").items == 0)
end

do
	local appended
	local closed = false

	with_temporary_value(package.loaded, "snacks", {
		picker = {
			pick = function(opts)
				assert(opts.items[1].label == "/skill:test-skill")
				opts.confirm({
					close = function()
						closed = true
					end,
				}, opts.items[1])
			end,
		},
	}, function()
		with_temporary_value(ai_skills, "list", function()
			return {
				{
					name = "test-skill",
					description = "Test skill",
					path = "/tmp/test-skill/SKILL.md",
				},
			}
		end, function()
			local prompt_builder = require("user.prompt_builder")
			with_temporary_value(prompt_builder, "append_text", function(text)
				appended = text
			end, function()
				ai_skills.pick_to_prompt_builder({ provider = "pi" })
			end)
		end)
	end)

	assert(appended == "/skill:test-skill", "expected Pi skill picker to append /skill:<name>")
	assert(closed, "expected skill picker to close after selection")
end

-- Reference payload contract: common owns formatting; Wiremux keeps compatibility wrappers.
assert(ai_action_common.format_context_ref_line({ relative_path = "foo/bar.lua" }) == "@foo/bar.lua")
assert(
	ai_action_common.format_context_ref_line({
		relative_path = "foo/bar.lua",
		selection = "x",
		start_line = 3,
		end_line = 9,
	})
		== "@foo/bar.lua lines 3-9"
)
assert(
	ai_action_common.format_reference_payload({
		items = {
			{
				type = "file",
				path = "lua/user/plugins/ai/wiremux.lua",
			},
			{
				type = "selection",
				path = "lua/user/snacks/ai_context_files.lua",
				start_line = 10,
				end_line = 22,
			},
		},
	}) == "@lua/user/plugins/ai/wiremux.lua\n@lua/user/snacks/ai_context_files.lua lines 10-22\n"
)

assert(wiremux_actions.format_context_ref_line({ relative_path = "foo/bar.lua" }) == "@foo/bar.lua")
assert(
	wiremux_actions.format_context_ref_line({
		relative_path = "foo/bar.lua",
		selection = "x",
		start_line = 3,
		end_line = 9,
	})
		== "@foo/bar.lua lines 3-9"
)
assert(
	wiremux_actions.format_reference_payload({
		type = "file",
		path = "lua/user/plugins/ai/wiremux.lua",
	}) == "@lua/user/plugins/ai/wiremux.lua\n"
)

assert(
	wiremux_actions.format_reference_payload({
		type = "selection",
		path = "lua/user/snacks/ai_context_files.lua",
		start_line = 42,
		end_line = 67,
	}) == "@lua/user/snacks/ai_context_files.lua lines 42-67\n"
)

assert(
	wiremux_actions.format_reference_payload({
		items = {
			{
				type = "file",
				path = "lua/user/plugins/ai/wiremux.lua",
			},
			{
				type = "selection",
				path = "lua/user/snacks/ai_context_files.lua",
				start_line = 10,
				end_line = 22,
			},
		},
	}) == "@lua/user/plugins/ai/wiremux.lua\n@lua/user/snacks/ai_context_files.lua lines 10-22\n"
)

do
	local sent_payloads = {}

	with_temporary_value(wiremux, "send_text", function(payload, opts)
		table.insert(sent_payloads, { payload = payload, opts = opts })
		return true
	end, function()
		assert(
			wiremux_actions.send_file({
				file_path = "/tmp/lua/user/plugins/ai/wiremux.lua",
				relative_path = "lua/user/plugins/ai/wiremux.lua",
			})
		)
		assert(sent_payloads[1].payload == "@lua/user/plugins/ai/wiremux.lua\n")

		assert(
			wiremux_actions.send_file({
				file_path = "/tmp/lua/user/snacks/ai_context_files.lua",
				relative_path = "lua/user/snacks/ai_context_files.lua",
				start_line = 10,
				end_line = 22,
			})
		)
		assert(sent_payloads[2].payload == "@lua/user/snacks/ai_context_files.lua lines 10-22\n")

		assert(
			wiremux_actions.send_reference_batch({
				{
					type = "file",
					path = "lua/user/plugins/ai/wiremux.lua",
				},
				{
					type = "selection",
					path = "lua/user/snacks/ai_context_files.lua",
					start_line = 10,
					end_line = 22,
				},
			})
		)
		assert(
			sent_payloads[3].payload
				== "@lua/user/plugins/ai/wiremux.lua\n@lua/user/snacks/ai_context_files.lua lines 10-22\n"
		)
	end)
end

do
	local ai_context_files = require("user.snacks.ai_context_files")
	local sent_refs
	local picker_closed = false
	local project_root = "/tmp/project-root"
	local file_path = project_root .. "/lua/user/snacks/ai_context_files.lua"

	with_temporary_cwd("/tmp", function()
		with_temporary_value(package.loaded, "snacks", {
			picker = {
				get = function()
					return {
						{
							selected = function()
								return {
									_path = file_path,
									cwd = project_root,
								}
							end,
							close = function()
								picker_closed = true
							end,
						},
					}
				end,
			},
		}, function()
			local prompt_builder = require("user.prompt_builder")
			with_temporary_value(prompt_builder, "append_references", function(refs)
				sent_refs = refs
			end, function()
				ai_context_files.add_file_to_chat(function(opts)
					opts.actions.custom_file_confirm()
				end)
			end)
		end)
	end)

	assert(picker_closed, "expected picker to close after confirming file selection")
	assert(sent_refs and #sent_refs == 1, "expected a single file reference to be sent")
	assert(sent_refs[1].kind == "file")
	assert(sent_refs[1].relative_path == "lua/user/snacks/ai_context_files.lua")
end

local repo_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(nvim_root)))
for _, rel_path in ipairs({
	"mods/dotfiles/nvim/lua/user/lazy.lua",
	"mods/dotfiles/nvim/lua/user/plugin_registry.lua",
	"mods/dotfiles/nvim/lua/user/snacks/commands/ai.lua",
	"mods/dotfiles/nvim/BEHAVIOR.md",
}) do
	local path = vim.fs.joinpath(repo_root, rel_path)
	local text = table.concat(vim.fn.readfile(path), "\n")
	assert(#text > 100, "readfile returned empty for " .. path .. " — CWD may be wrong")
	assert(not text:match("CodeCompanion"), "Found CodeCompanion reference in " .. path)
	assert(not text:match("codecompanion"), "Found codecompanion reference in " .. path)
	assert(not text:match("<leader>O"), "Found <leader>O reference in " .. path)
end

print("ai_wiremux_migration_spec: ok")
