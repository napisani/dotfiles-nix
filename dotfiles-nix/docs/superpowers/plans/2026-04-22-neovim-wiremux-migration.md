# Neovim Wiremux Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Agentic, CodeCompanion, and CodeExplain from the Neovim config, move the surviving agent workflow onto `<leader>o`, and rewrite file-context flows to send lightweight Wiremux references.

**Architecture:** Keep `lua/user/plugins/ai/wiremux.lua` as the only active general-purpose AI transport, simplify shared helper modules so they no longer branch across backends, and add a small headless Lua test harness that asserts the keymap contract and Wiremux reference payload behavior. Rewrite `lua/user/snacks/ai_context_files.lua` around lightweight file and line-range references instead of in-editor chat attachments.

**Tech Stack:** Neovim Lua config, lazy.nvim, which-key plugin discovery, snacks.nvim pickers, wiremux.nvim, headless `nvim` verification.

---

### Task 1: Add a headless regression harness for AI keymaps and reference payloads

**Files:**
- Create: `mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua`
- Modify: `mods/dotfiles/nvim/lua/user/plugins/ai/wiremux.lua`
- Modify: `mods/dotfiles/nvim/lua/user/snacks/ai_actions/wiremux.lua`

- [ ] **Step 1: Write the failing test file**

```lua
local function has_mapping(entries, lhs)
	for _, entry in ipairs(entries or {}) do
		if entry[1] == lhs then
			return true, entry
		end
	end
	return false, nil
end

local wiremux_plugin = require("user.plugins.ai.wiremux")
local wiremux_actions = require("user.snacks.ai_actions.wiremux")

local keymaps = wiremux_plugin.get_keymaps()

assert(has_mapping(keymaps.normal, "<leader>oo"))
assert(has_mapping(keymaps.normal, "<leader>o?"))
assert(has_mapping(keymaps.normal, "<leader>op"))
assert(has_mapping(keymaps.normal, "<leader>os"))
assert(has_mapping(keymaps.normal, "<leader>oq"))
assert(has_mapping(keymaps.normal, "<leader>ox"))
assert(has_mapping(keymaps.visual, "<leader>oa"))

assert(not has_mapping(keymaps.normal, "<leader>Oo"))
assert(not has_mapping(keymaps.normal, "<leader>OP"))
assert(not has_mapping(keymaps.normal, "<leader>OS"))

local full_ref = wiremux_actions.format_reference_payload({
	items = {
		{ kind = "file", relative_path = "lua/user/plugins/ai/wiremux.lua" },
	},
})
assert(full_ref == "Context references:\n- file: lua/user/plugins/ai/wiremux.lua")

local selection_ref = wiremux_actions.format_reference_payload({
	items = {
		{ kind = "selection", relative_path = "lua/user/snacks/ai_context_files.lua", start_line = 42, end_line = 67 },
	},
})
assert(selection_ref == "Context references:\n- selection: lua/user/snacks/ai_context_files.lua:42-67")

print("ai_wiremux_migration_spec: ok")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `nvim --headless -u mods/dotfiles/nvim/init.vim -c "lua dofile('mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua')" -c "qa"`
Expected: FAIL because the current keymaps still expose `<leader>O...` and `user.snacks.ai_actions.wiremux` does not yet export `format_reference_payload()`.

- [ ] **Step 3: Add minimal test hooks to the Wiremux modules**

```lua
-- mods/dotfiles/nvim/lua/user/snacks/ai_actions/wiremux.lua

function M.format_reference_payload(spec)
	local lines = { "Context references:" }
	for _, item in ipairs(spec.items or {}) do
		if item.kind == "selection" then
			table.insert(lines, string.format("- selection: %s:%d-%d", item.relative_path, item.start_line, item.end_line))
		else
			table.insert(lines, string.format("- file: %s", item.relative_path))
		end
	end
	return table.concat(lines, "\n")
end
```

```lua
-- mods/dotfiles/nvim/lua/user/plugins/ai/wiremux.lua

function M.missing_feature_stub(message)
	return function()
		vim.notify(message, vim.log.levels.INFO)
	end
end
```

- [ ] **Step 4: Re-run the test to confirm the helper surface exists**

Run: `nvim --headless -u mods/dotfiles/nvim/init.vim -c "lua dofile('mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua')" -c "qa"`
Expected: still FAIL, but now only on keymap expectations.

- [ ] **Step 5: Commit the harness**

```bash
git add mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua mods/dotfiles/nvim/lua/user/plugins/ai/wiremux.lua mods/dotfiles/nvim/lua/user/snacks/ai_actions/wiremux.lua
git commit -m "test: add wiremux migration regression harness"
```

### Task 2: Move the active agent namespace from `<leader>O` to `<leader>o`

**Files:**
- Modify: `mods/dotfiles/nvim/lua/user/plugins/ai/wiremux.lua`
- Test: `mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua`

- [ ] **Step 1: Update the failing keymap expectations if needed**

```lua
-- Confirm these explicit expectations remain in the spec file.
assert(has_mapping(keymaps.normal, "<leader>on"))
assert(has_mapping(keymaps.normal, "<leader>ow"))
assert(has_mapping(keymaps.normal, "<leader>om"))
assert(has_mapping(keymaps.normal, "<leader>oz"))
assert(has_mapping(keymaps.normal, "<leader>oe"))
assert(not has_mapping(keymaps.normal, "<leader>O?"))
assert(not has_mapping(keymaps.visual, "<leader>Oa"))
```

- [ ] **Step 2: Run the test and confirm it fails on the old keymaps**

Run: `nvim --headless -u mods/dotfiles/nvim/init.vim -c "lua dofile('mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua')" -c "qa"`
Expected: FAIL because `get_keymaps()` still returns uppercase Wiremux bindings and does not expose the stubbed lowercase entries.

- [ ] **Step 3: Rewrite `get_keymaps()` in `wiremux.lua` to the new contract**

```lua
function M.get_keymaps()
	local stub = M.missing_feature_stub
	return {
		normal = {
			{ "<leader>o", group = "Wiremux" },
			{ "<leader>oo", M.toggle_target, desc = "toggle agent" },
			{ "<leader>o?", function()
				prompt_input(false)
			end, desc = "prompt" },
			{ "<leader>op", pick_prompt, desc = "prompt library" },
			{ "<leader>os", M.select_route, desc = "select route" },
			{ "<leader>oq", M.close_target, desc = "close target" },
			{ "<leader>ox", M.close_target, desc = "close target" },
			{ "<leader>on", stub("Wiremux new-session flow is not implemented yet"), desc = "new session" },
			{ "<leader>ow", stub("Wiremux model switching is not implemented yet"), desc = "switch model" },
			{ "<leader>om", stub("Wiremux mode switching is not implemented yet"), desc = "switch mode" },
			{ "<leader>oz", stub("Wiremux zoom/layout control is not implemented yet"), desc = "zoom" },
			{ "<leader>oe", stub("Wiremux edit/build shortcut is not implemented yet"), desc = "edit" },
		},
		visual = {
			{ "<leader>o", group = "Wiremux" },
			{ "<leader>oa", function()
				prompt_input(true)
			end, desc = "ask selection" },
			{ "<leader>o?", function()
				prompt_input(true)
			end, desc = "prompt selection" },
		},
		shared = {},
	}
end
```

- [ ] **Step 4: Re-run the migration spec**

Run: `nvim --headless -u mods/dotfiles/nvim/init.vim -c "lua dofile('mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua')" -c "qa"`
Expected: PASS for the keymap assertions.

- [ ] **Step 5: Commit the keymap migration**

```bash
git add mods/dotfiles/nvim/lua/user/plugins/ai/wiremux.lua mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua
git commit -m "feat: move wiremux agent actions to leader-o"
```

### Task 3: Rewrite Wiremux reference formatting for file and visual context flows

**Files:**
- Modify: `mods/dotfiles/nvim/lua/user/snacks/ai_actions/wiremux.lua`
- Modify: `mods/dotfiles/nvim/lua/user/snacks/ai_actions/common.lua`
- Test: `mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua`

- [ ] **Step 1: Extend the test file with explicit line-range and batch assertions**

```lua
local batch_ref = wiremux_actions.format_reference_payload({
	items = {
		{ kind = "file", relative_path = "lua/user/plugins/ai/wiremux.lua" },
		{ kind = "selection", relative_path = "lua/user/snacks/ai_context_files.lua", start_line = 10, end_line = 22 },
	},
})

assert(batch_ref == table.concat({
	"Context references:",
	"- file: lua/user/plugins/ai/wiremux.lua",
	"- selection: lua/user/snacks/ai_context_files.lua:10-22",
}, "\n"))
```

- [ ] **Step 2: Run the spec and confirm the new assertions fail**

Run: `nvim --headless -u mods/dotfiles/nvim/init.vim -c "lua dofile('mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua')" -c "qa"`
Expected: FAIL until the formatter consistently handles batch items and line ranges.

- [ ] **Step 3: Implement the reference formatter and selection-aware send helpers**

```lua
-- mods/dotfiles/nvim/lua/user/snacks/ai_actions/wiremux.lua

local function to_reference_item(file_info)
	if file_info.start_line and file_info.end_line then
		return {
			kind = "selection",
			relative_path = file_info.relative_path,
			start_line = file_info.start_line,
			end_line = file_info.end_line,
		}
	end
	return {
		kind = "file",
		relative_path = file_info.relative_path,
	}
end

function M.send_file(file_info, _opts)
	local plugin = ensure_plugin()
	if not plugin or not file_info or not file_info.file_path then
		return false
	end
	local payload = M.format_reference_payload({
		items = { to_reference_item(file_info) },
	})
	return plugin.send_text(payload, { focus = true })
end

function M.send_reference_batch(items)
	local plugin = ensure_plugin()
	if not plugin then
		return false
	end
	local payload = M.format_reference_payload({ items = items })
	return plugin.send_text(payload, { focus = true })
end
```

```lua
-- mods/dotfiles/nvim/lua/user/snacks/ai_actions/common.lua

function M.format_line_range(ctx)
	if ctx.start_line and ctx.end_line then
		return string.format("%s:%d-%d", ctx.relative_path or ctx.file_path, ctx.start_line, ctx.end_line)
	end
	return M.format_file_ref(ctx, M.REF_STYLE_AT)
end
```

- [ ] **Step 4: Re-run the migration spec**

Run: `nvim --headless -u mods/dotfiles/nvim/init.vim -c "lua dofile('mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua')" -c "qa"`
Expected: PASS, including the batch-reference assertions.

- [ ] **Step 5: Commit the payload rewrite**

```bash
git add mods/dotfiles/nvim/lua/user/snacks/ai_actions/wiremux.lua mods/dotfiles/nvim/lua/user/snacks/ai_actions/common.lua mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua
git commit -m "feat: send lightweight wiremux context references"
```

### Task 4: Rewrite `ai_context_files.lua` and the shared AI dispatcher around Wiremux-only behavior

**Files:**
- Modify: `mods/dotfiles/nvim/lua/user/snacks/ai_context_files.lua`
- Modify: `mods/dotfiles/nvim/lua/user/snacks/ai_actions.lua`
- Modify: `mods/dotfiles/nvim/lua/user/snacks/ai_actions/wiremux.lua`
- Test: `mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua`

- [ ] **Step 1: Add a failing test for the Wiremux-only dispatcher contract**

```lua
local ai_actions = require("user.snacks.ai_actions")
assert(type(ai_actions.prompt_with_context) == "function")
assert(type(ai_actions.stage_context) == "function")

local source = vim.fn.readfile("mods/dotfiles/nvim/lua/user/snacks/ai_actions.lua")
local joined = table.concat(source, "\n")
assert(not joined:match("codecompanion"))
assert(not joined:match("agentic"))
```

- [ ] **Step 2: Run the spec and confirm it fails on the old backend dispatcher**

Run: `nvim --headless -u mods/dotfiles/nvim/init.vim -c "lua dofile('mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua')" -c "qa"`
Expected: FAIL because `ai_actions.lua` still requires CodeCompanion and Agentic modules.

- [ ] **Step 3: Replace the backend branching with Wiremux-only code paths**

```lua
-- mods/dotfiles/nvim/lua/user/snacks/ai_actions.lua

local wiremux = require("user.snacks.ai_actions.wiremux")
local common = require("user.snacks.ai_actions.common")

local function get_backend()
	return wiremux
end
```

```lua
-- mods/dotfiles/nvim/lua/user/snacks/ai_context_files.lua

local wiremux_actions = require("user.snacks.ai_actions.wiremux")
local file_utils = require("user.utils.file_utils")

function M.add_current_buffer_to_chat()
	local file_path, bufnr = get_current_file_path()
	if not file_path then
		return
	end
	local file_info = {
		file_path = file_path,
		relative_path = vim.fn.fnamemodify(file_path, ":."),
		bufnr = bufnr,
	}
	wiremux_actions.send_file(file_info, { source = "current_buffer" })
end

function M.add_file_to_chat(picker_fn, picker_opts)
	local function custom_confirm_action()
		local Snacks = require("snacks")
		local active_picker = Snacks.picker.get({ source = true })[1]
		local selection = active_picker:selected({ fallback = true })
		active_picker:close()

		local refs = {}
		process_selection(selection, function(sel)
			local fi = coerce_and_validate_selection(sel)
			if fi then
				table.insert(refs, {
					kind = "file",
					relative_path = fi.relative_path,
				})
			end
		end)

		wiremux_actions.send_reference_batch(refs)
	end
	-- existing picker_opts wiring stays, but always calls custom_confirm_action
end
```

- [ ] **Step 4: Re-run the migration spec**

Run: `nvim --headless -u mods/dotfiles/nvim/init.vim -c "lua dofile('mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua')" -c "qa"`
Expected: PASS, confirming the shared dispatcher and file-context helper no longer depend on removed backends.

- [ ] **Step 5: Commit the Wiremux-only helper rewrite**

```bash
git add mods/dotfiles/nvim/lua/user/snacks/ai_context_files.lua mods/dotfiles/nvim/lua/user/snacks/ai_actions.lua mods/dotfiles/nvim/lua/user/snacks/ai_actions/wiremux.lua mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua
git commit -m "refactor: make ai context helpers wiremux-only"
```

### Task 5: Remove the old plugins and update commands and behavior docs

**Files:**
- Modify: `mods/dotfiles/nvim/lua/user/lazy.lua`
- Modify: `mods/dotfiles/nvim/lua/user/plugin_registry.lua`
- Delete: `mods/dotfiles/nvim/lua/user/plugins/ai/agentic.lua`
- Delete: `mods/dotfiles/nvim/lua/user/plugins/ai/codecompanion.lua`
- Delete: `mods/dotfiles/nvim/lua/user/plugins/ai/code_explain.lua`
- Delete: `mods/dotfiles/nvim/lua/user/snacks/ai_actions/agentic.lua`
- Delete: `mods/dotfiles/nvim/lua/user/snacks/ai_actions/codecompanion.lua`
- Modify: `mods/dotfiles/nvim/lua/user/snacks/commands/ai.lua`
- Modify: `mods/dotfiles/nvim/lua/user/blink.lua`
- Modify: `mods/dotfiles/nvim/BEHAVIOR.md`
- Test: `mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua`

- [ ] **Step 1: Add a failing static check for removed plugin references**

```lua
for _, path in ipairs({
	"mods/dotfiles/nvim/lua/user/lazy.lua",
	"mods/dotfiles/nvim/lua/user/plugin_registry.lua",
	"mods/dotfiles/nvim/lua/user/snacks/commands/ai.lua",
	"mods/dotfiles/nvim/BEHAVIOR.md",
}) do
	local text = table.concat(vim.fn.readfile(path), "\n")
	assert(not text:match("CodeCompanion"))
	assert(not text:match("codecompanion"))
	assert(not text:match("agentic"))
	assert(not text:match("<leader>O"))
end
```

- [ ] **Step 2: Run the static check and confirm it fails**

Run: `nvim --headless -u mods/dotfiles/nvim/init.vim -c "lua dofile('mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua')" -c "qa"`
Expected: FAIL because the old plugin specs, registry entries, command palette entries, and behavior docs are still present.

- [ ] **Step 3: Remove the old plugins and rewrite the docs/commands**

```lua
-- mods/dotfiles/nvim/lua/user/lazy.lua
{
	"MSmaili/wiremux.nvim",
	config = function(_, opts)
		require("user.plugins.ai.wiremux").setup(opts)
	end,
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
},
```

```lua
-- mods/dotfiles/nvim/lua/user/plugin_registry.lua
	"ai.copilot",
	"ai.wiremux",
	"ai.vocal",
```

```lua
-- mods/dotfiles/nvim/lua/user/snacks/commands/ai.lua
local gp_group = "AI > "
local commands = {
	{
		"lua require('user.plugins.ai.wiremux').focus_target()",
		description = gp_group .. "Focus Wiremux target",
	},
}
```

```markdown
<!-- mods/dotfiles/nvim/BEHAVIOR.md -->
## `<leader>o` — Wiremux (external agent pane)

`<leader>o` -> domain: send prompts and context references to an external agent running in a tmux pane
`<leader>oo` -> [n] leaf: show or hide the current route target and focus it
`<leader>o?` -> [nv] leaf: prompt for instructions and send to the current route
`<leader>op` -> [n] leaf: pick a canned prompt and send it to the current route
`<leader>os` -> [n] leaf: select the active route/backend
`<leader>oq` -> [n] leaf: close the current route target
`<leader>ox` -> [n] leaf: close the current route target
`<leader>oa` -> [v] leaf: send a lightweight filename plus line-range reference for the visual selection

## `<leader>af` — AI context file references

`<leader>af...` -> domain: send lightweight file references to the active Wiremux route
`<leader>aff` -> leaf: send the current file path as a lightweight reference
`<leader>afe` -> leaf: pick from open buffers and send file references
```

- [ ] **Step 4: Run the full validation set**

Run: `nvim --headless -u mods/dotfiles/nvim/init.vim -c "lua dofile('mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua')" -c "qa"`
Expected: PASS with `ai_wiremux_migration_spec: ok`

Run: `nvim --headless -u mods/dotfiles/nvim/init.vim -c "lua require('user.plugins.ai.wiremux')" -c "qa"`
Expected: exit 0

Run: `nvim --headless -u mods/dotfiles/nvim/init.vim -c "lua local p = require('user.whichkey.plugins'); print(vim.inspect(p.get_all_plugin_keymaps()))" -c "qa"`
Expected: output includes `<leader>o` mappings and does not include `<leader>O`

Run: `nvim --headless -u mods/dotfiles/nvim/init.vim -c "checkhealth" -c "qa"`
Expected: no Agentic or CodeCompanion health errors; Wiremux still loads

- [ ] **Step 5: Commit the cull and documentation updates**

```bash
git add mods/dotfiles/nvim/lua/user/lazy.lua mods/dotfiles/nvim/lua/user/plugin_registry.lua mods/dotfiles/nvim/lua/user/snacks/commands/ai.lua mods/dotfiles/nvim/lua/user/blink.lua mods/dotfiles/nvim/BEHAVIOR.md mods/dotfiles/nvim/tests/ai_wiremux_migration_spec.lua
git add -u mods/dotfiles/nvim/lua/user/plugins/ai mods/dotfiles/nvim/lua/user/snacks/ai_actions
git commit -m "refactor: migrate neovim agent workflows to wiremux"
```

## Self-Review

- Spec coverage: the plan covers the plugin cull, `<leader>o` migration, `<leader>O` removal, explicit stubs, Wiremux-only helper rewrite, lightweight file and line-range references for `<leader>af...`, and behavior/doc verification.
- Placeholder scan: no `TODO`, `TBD`, or “test later” placeholders remain; each task lists exact files, commands, and code examples.
- Type consistency: the plan consistently uses `format_reference_payload`, `send_reference_batch`, and `missing_feature_stub` across the tasks.
