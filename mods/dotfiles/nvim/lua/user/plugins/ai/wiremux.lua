---@diagnostic disable: undefined-global

local M = {}
local ai_prompts = require("user.plugins.ai.ai_prompts")


local default_config = {
	default_route = "pi",
	prompts = ai_prompts.defaults,
	targets = {
		definitions = {
			claude = {
				label = "Claude Code",
				cmd = "claude --allow-dangerously-skip-permissions",
				kind = "pane",
				split = "horizontal", -- horizontal split -> pane opens on the right
				shell = false,
			},
			codex = {
				label = "Codex",
				cmd = "codex",
				kind = "pane",
				split = "horizontal",
				shell = false,
			},
			cursor_agent = {
				label = "Cursor Agent",
				cmd = "agent",
				kind = "pane",
				split = "horizontal",
				shell = false,
			},
			gemini = {
				label = "Gemini",
				cmd = "gemini",
				kind = "pane",
				split = "horizontal",
				shell = false,
			},
			opencode = {
				label = "OpenCode",
				cmd = "opencode",
				kind = "pane",
				split = "horizontal", -- horizontal split -> pane opens on the right
				shell = false,
			},
			pi = {
				label = "Pi",
				cmd = "pi",
				kind = "pane",
				split = "horizontal",
				shell = false,
			},
		},
	},
	actions = {
		send = { behavior = "last", focus = true },
		toggle = { behavior = "last", focus = true },
		focus = { behavior = "last", focus = true },
		create = { behavior = "pick", focus = true },
	},
}

local state = {
	current_route = default_config.default_route,
	options = vim.deepcopy(default_config),
	configured = false,
}

local function get_backend()
	local ok, backend_mod = pcall(require, "wiremux.backend")
	if not ok then
		return nil
	end
	return backend_mod.get()
end

local function notify_missing()
	vim.notify("wiremux.nvim is not available", vim.log.levels.ERROR)
end

local function ensure_wiremux()
	local ok, wiremux = pcall(require, "wiremux")
	if not ok then
		notify_missing()
		return nil
	end
	return wiremux
end

local function get_route_definition(name)
	return state.options.targets
		and state.options.targets.definitions
		and state.options.targets.definitions[name]
end

local function set_current_route(name)
	if not name or name == "" then
		return
	end
	if get_route_definition(name) then
		state.current_route = name
	else
		vim.notify(string.format("wiremux: unknown route '%s'", name), vim.log.levels.WARN)
	end
end

local function normalize_picker_items(items)
	local normalized = {}
	for _, item in ipairs(items or {}) do
		if type(item) == "table" then
			local copy = vim.tbl_deep_extend("force", {}, item)
			if not copy.text then
				copy.text = copy.label or copy.name or copy.value or tostring(copy)
			end
			table.insert(normalized, copy)
		else
			local text = tostring(item)
			table.insert(normalized, {
				text = text,
				label = text,
				name = text,
				value = item,
			})
		end
	end
	return normalized
end

local function with_snacks_picker(opts, on_choice)
	local ok, Snacks = pcall(require, "snacks")
	if ok and Snacks.picker and Snacks.picker.pick then
		local items = normalize_picker_items(opts.items)
		Snacks.picker.pick({
			items = items,
			prompt = opts.prompt,
			format = opts.format or "text",
			preview = opts.preview or "none",
			format_item = opts.format_item,
			confirm = function(picker, item)
				if item then
					on_choice(item)
				end
				if picker and picker.close then
					picker:close()
				end
			end,
		})
	else
		vim.ui.select(opts.items, {
			prompt = opts.prompt,
			format_item = opts.format_item,
		}, on_choice)
	end
end

-- Find a same-session managed instance for the route whose origin_cwd matches cwd.
local function find_cwd_instance(instances, route, cwd, session_id)
	for _, inst in ipairs(instances) do
		if inst.target == route and inst.origin_cwd == cwd
			and (not session_id or inst.session_id == session_id) then
			return inst
		end
	end
	return nil
end

-- Fallback: any managed instance for the route in the given session, regardless of CWD.
-- Scoped to session so remote-session claude instances don't pollute routing.
local function find_any_route_instance(instances, route, session_id)
	for _, inst in ipairs(instances) do
		if inst.target == route and (not session_id or inst.session_id == session_id) then
			return inst
		end
	end
	return nil
end

-- Find an unmanaged tmux pane (no @wiremux_target) in the current session that is
-- running the route's executable. Uses TTY-based ps so node-wrapped binaries
-- (e.g. claude → node) are detected even when #{pane_pid} only shows the shell.
-- Returns a wiremux.Pane object, or nil.
local function find_unmanaged_pane_running(route, st)
	local def = get_route_definition(route)
	if not def or not def.cmd then return nil end
	local exe = def.cmd:match("^(%S+)")
	if not exe then return nil end
	exe = vim.fn.fnamemodify(exe, ":t")

	local managed_ids = {}
	for _, inst in ipairs(st.instances or {}) do
		managed_ids[inst.id] = true
	end
	-- Never adopt the nvim pane itself. st.origin_pane_id can be wrong when tmux
	-- focus has moved (display -p tracks focused pane, not nvim's pane), so prefer
	-- TMUX_PANE which is set at nvim startup and is stable.
	local nvim_pane_id = vim.env.TMUX_PANE or st.origin_pane_id
	if nvim_pane_id then
		managed_ids[nvim_pane_id] = true
	end

	local pane_map = {}
	for _, pane in ipairs(st.panes or {}) do
		pane_map[pane.id] = pane
	end

	local current_session = st.session_id
	local out = vim.fn.system("tmux list-panes -a -F '#{pane_id} #{session_id} #{pane_tty}' 2>/dev/null")
	for line in out:gmatch("[^\n]+") do
		local pane_id, session_id, pane_tty = line:match("^(%%%d+)%s+(%S+)%s+(.+)$")
		if pane_id and session_id == current_session and pane_tty and not managed_ids[pane_id] then
			local procs = vim.fn.system(string.format("ps -t %s -o args= 2>/dev/null", pane_tty))
			if procs:find(exe, 1, true) then
				return pane_map[pane_id] or { id = pane_id, kind = "pane" }
			end
		end
	end
	return nil
end

local function reuse_instance(existing)
	local tmux_state = require("wiremux.backend.tmux.state")
	local batch = {}
	tmux_state.update_last_used(batch, existing.id)
	require("wiremux.backend.tmux.client").execute(batch)
end

-- Ensure a wiremux-tracked instance exists for the route before send/toggle/focus.
-- Only considers instances in the current tmux session to avoid accidentally routing
-- to or triggering a picker over claude panes in unrelated sessions.
-- Managed same-session instances are reused; unmanaged same-session panes running
-- the route's process are adopted. Returns false when nothing is found — wiremux.send()
-- handles creation via its on_definition callback.
local function ensure_route_instance(route)
	if not route or route == "" then return false end
	local backend = get_backend()
	if not backend or not backend.state then return false end
	local st = backend.state.get()
	local cwd = vim.fn.getcwd()

	-- 1. Managed instance in the same session: prefer CWD match, then any CWD.
	if st.instances then
		local existing = find_cwd_instance(st.instances, route, cwd, st.session_id)
			or find_any_route_instance(st.instances, route, st.session_id)
		if existing then
			reuse_instance(existing)
			return true
		end
	end

	-- 2. Unmanaged same-session pane running the route's process: adopt it.
	local unmanaged = find_unmanaged_pane_running(route, st)
	if unmanaged then
		local ok, tmux_state = pcall(require, "wiremux.backend.tmux.state")
		if ok then
			if tmux_state.adopt(unmanaged, st, route) then return true end
		end
	end

	-- 3. Nothing found — let wiremux.send() create via its on_definition callback.
	return false
end

function M.setup(user_opts)
	local wiremux = ensure_wiremux()
	if not wiremux then
		return
	end

	local merged = vim.tbl_deep_extend("force", vim.deepcopy(default_config), user_opts or {})
	state.options = merged
	state.current_route = merged.default_route or merged.targets.default_route or default_config.default_route

	wiremux.setup(merged)
	state.configured = true
end

function M.is_available()
	return state.configured and ensure_wiremux() ~= nil
end

function M.get_current_route()
	return state.current_route
end

function M.get_route_definitions()
	return state.options.targets and state.options.targets.definitions or {}
end

local function send_via_wiremux(payload, opts)
	if not payload or payload == "" then
		return false
	end
	local wiremux = ensure_wiremux()
	if not wiremux then
		return false
	end
	opts = opts or {}
	opts.target = opts.target or state.current_route
	ensure_route_instance(opts.target)
	opts.behavior = opts.behavior or "last"
	if opts.focus == nil then
		opts.focus = true
	end
	-- Upstream default is often submit=false; we want Enter/Submit in the target pane.
	if opts.submit == nil then
		opts.submit = true
	end
	-- Restrict routing to the current tmux session so remote-session claude instances
	-- don't intercept sends or trigger a multi-choice picker.
	if not opts.filter then
		opts.filter = {
			instances = function(inst, st)
				return inst.session_id == st.session_id
			end,
		}
	end
	-- Refocus nvim's pane before send so wiremux's internal `display -p` (no -t)
	-- returns nvim's pane ID as origin_pane_id. If a previous send with focus=true
	-- moved tmux focus to the target pane, wiremux would mistake the target pane for
	-- the origin and exclude it from routing — creating a duplicate pane instead.
	local nvim_pane = vim.env.TMUX_PANE
	if nvim_pane and nvim_pane ~= "" then
		vim.fn.system("tmux select-pane -t " .. nvim_pane)
	end
	local ok, err = pcall(wiremux.send, payload, opts)
	if not ok then
		vim.notify("wiremux send failed: " .. tostring(err), vim.log.levels.ERROR)
		return false
	end
	return true
end

function M.send_text(text, opts)
	return send_via_wiremux(text, opts)
end

function M.send_selection()
	return send_via_wiremux("{selection}")
end

function M.toggle_target()
	local wiremux = ensure_wiremux()
	if not wiremux then
		return false
	end
	wiremux.toggle({ target = state.current_route, behavior = "last", focus = true })
	return true
end

function M.focus_target()
	local wiremux = ensure_wiremux()
	if not wiremux then
		return false
	end
	wiremux.focus({ target = state.current_route, behavior = "last", focus = true })
	return true
end

function M.close_target()
	local wiremux = ensure_wiremux()
	if not wiremux then
		return false
	end
	wiremux.close({ target = state.current_route, behavior = "all" })
	return true
end

local function list_routes()
	local defs = state.options.targets and state.options.targets.definitions or {}
	local items = {}
	for name, def in pairs(defs) do
		table.insert(items, {
			name = name,
			label = def.label or name,
		})
	end
	table.sort(items, function(a, b)
		return a.label < b.label
	end)
	return items
end

function M.select_route()
	local items = list_routes()
	with_snacks_picker({
		items = items,
		prompt = "Wiremux Routes",
		format_item = function(item)
			if not item then
				return ""
			end
			local marker = item.name == state.current_route and "* " or "  "
			return marker .. (item.label or item.name or item.text or "")
		end,
	}, function(item)
		if not item then
			return
		end
		set_current_route(item.name)
		vim.notify(string.format("Wiremux route switched to %s", item.label), vim.log.levels.INFO)
	end)
end

--- Canned template placeholders: {file} {this} {selection} (selection empty when not in visual)
local function expand_prompt_template(value)
	if not value then
		return ""
	end
	local s = tostring(value)
	local rel = vim.fn.expand("%:.")
	if rel == "" then
		rel = "(no file name)"
	end
	s = s:gsub("{file}", rel)
	s = s:gsub("{this}", rel)
	-- Canned pick runs from normal mode after the picker; selection not available
	s = s:gsub("{selection}", "")
	return s
end

local function prompt_picker_items()
	local items = {}
	for _, prompt in ipairs(state.options.prompts or ai_prompts.defaults) do
		local item = vim.tbl_deep_extend("force", {}, prompt)
		item.text = item.label or item.value or ""
		item.preview = {
			text = item.value or "",
			ft = "markdown",
			loc = false,
		}
		table.insert(items, item)
	end
	return items
end

local function pick_prompt()
	with_snacks_picker({
		items = prompt_picker_items(),
		prompt = "Canned prompts → PromptBuilder",
		preview = "preview",
		format_item = function(item)
			if not item then
				return ""
			end
			return item.label or item.value or item.text or ""
		end,
	}, function(item)
		if not item or not item.value then
			return
		end
		local body = expand_prompt_template(item.value)
		if body and body ~= "" then
			require("user.prompt_builder").append_text(body)
		end
	end)
end

--- Wire file-reference pickers into send_reference_batch (CR confirms).
local function add_refs_from_picker(open_picker)
	require("user.snacks.ai_context_files").add_file_to_chat(open_picker)
end

local function ref_from_buffers()
	add_refs_from_picker(function(opts)
		return require("snacks").picker.buffers(opts)
	end)
end

local function ref_from_repo_root()
	add_refs_from_picker(function(opts)
		return require("user.snacks.find_files").find_files_from_root(opts)
	end)
end

local function ref_from_git_tracked()
	add_refs_from_picker(function(opts)
		return require("snacks").picker.git_files(opts)
	end)
end

local function ref_from_git_changed()
	add_refs_from_picker(function(opts)
		return require("user.snacks.git_files").git_changed_files(opts)
	end)
end

local function ref_from_git_branch_diff()
	add_refs_from_picker(function(opts)
		return require("user.snacks.git_files").git_changed_cmp_base_branch(opts)
	end)
end

local function ref_from_git_conflicts()
	add_refs_from_picker(function(opts)
		return require("user.snacks.git_files").git_conflicted_files(opts)
	end)
end

local function snack_context_to_builder(mode, input_prompt, body_label)
	require("user.snacks.ai_actions").append_snack_context_to_prompt_builder({
		mode = mode,
		input_prompt = input_prompt,
		body_label = body_label,
	})
end

function M.get_keymaps()
	local ai_context = "user.snacks.ai_context_files"
	return {
		normal = {
			{ "<leader>a", group = "Wiremux + PromptBuilder" },
			{ "<leader>ai", function()
				require("user.prompt_builder").open_or_focus()
			end, desc = "open/focus PromptBuilder" },
			{ "<leader>ao", M.toggle_target, desc = "show/hide route target" },
			{ "<leader>aq", M.close_target, desc = "close target" },
			{ "<leader>av", "<cmd>Vocal<cr>", desc = "voice" },
			{ "<leader>af", group = "file refs → builder" },
			{ "<leader>afe", ref_from_buffers, desc = "ref buffers → builder" },
			{ "<leader>aff", function()
				require(ai_context).add_current_buffer_to_chat()
			end, desc = "ref current file (aff) → builder" },
			{ "<leader>afp", function()
				require(ai_context).add_parent_path_file_to_chat()
			end, desc = "ref path file → builder" },
			{ "<leader>afr", ref_from_repo_root, desc = "ref from repo → builder" },
			{ "<leader>aft", ref_from_git_tracked, desc = "ref git files → builder" },
			{ "<leader>afd", ref_from_git_changed, desc = "ref unstaged → builder" },
			{ "<leader>afD", ref_from_git_branch_diff, desc = "ref vs base → builder" },
			{ "<leader>afC", ref_from_git_conflicts, desc = "ref conflicts → builder" },
			{ "<leader>ae", function()
				snack_context_to_builder("n", "Instruction", "Instruction")
			end, desc = "instruction (Snacks) → builder" },
			{ "<leader>a?", function()
				snack_context_to_builder("n", "Question", "Question")
			end, desc = "question (Snacks) → builder" },
			{ "<leader>as", function()
				require("user.snacks.ai_skills").pick_to_prompt_builder()
			end, desc = "skill → builder" },
			{ "<leader>ap", pick_prompt, desc = "canned prompt → builder" },
			{ "<leader>am", function()
				require("user.snacks.ai_actions").append_memo_to_prompt_builder({ mode = "n" })
			end, desc = "instructions (Snacks) → builder" },
			{ "<leader>aw", M.select_route, desc = "select route" },
		},
		visual = {
			{ "<leader>a", group = "Wiremux + PromptBuilder" },
			{ "<leader>ai", function()
				require("user.prompt_builder").open_or_focus()
			end, desc = "open/focus PromptBuilder" },
			{ "<leader>av", "<cmd>Vocal<cr>", desc = "voice" },
			{ "<leader>af", group = "file refs → builder" },
			{ "<leader>aff", function()
				require(ai_context).add_visual_range_to_chat()
			end, desc = "ref line range (aff) → builder" },
			{ "<leader>ae", function()
				snack_context_to_builder("v", "Instruction", "Instruction")
			end, desc = "instruction (Snacks) + range → builder" },
			{ "<leader>a?", function()
				snack_context_to_builder("v", "Question", "Question")
			end, desc = "question (Snacks) + range → builder" },
			{ "<leader>am", function()
				require("user.snacks.ai_actions").append_memo_to_prompt_builder({ mode = "v" })
			end, desc = "instructions (Snacks) + range → builder" },
		},
		shared = {},
	}
end

return M
