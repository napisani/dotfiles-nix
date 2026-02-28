---@diagnostic disable: undefined-global

local M = {}

local default_prompts = {
	{ label = "Explain selection", value = "Explain the following selection in detail:\n{selection}" },
	{ label = "Review selection", value = "Review this selection for potential issues:\n{selection}" },
	{ label = "Summarize file", value = "Summarize the key points from {file}" },
	{ label = "Suggest improvements", value = "How can we improve {this}?" },
	{ label = "Generate tests", value = "Write tests that cover this code:\n{selection}" },
}

local default_config = {
	default_route = "opencode",
	prompts = default_prompts,
	targets = {
		definitions = {
			opencode = {
				label = "OpenCode",
				cmd = "opencode",
				kind = "pane",
				split = "horizontal", -- horizontal split -> pane opens on the right
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

local function with_snacks_picker(opts, on_choice)
	local ok, Snacks = pcall(require, "snacks")
	if ok and Snacks.picker and Snacks.picker.pick then
		Snacks.picker.pick({
			items = opts.items,
			prompt = opts.prompt,
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

local function with_snacks_input(prompt, cb)
	local ok, Snacks = pcall(require, "snacks")
	if ok and Snacks.input then
		Snacks.input({ prompt = prompt }, function(value)
			if value and value ~= "" then
				cb(value)
			end
		end)
	else
		local value = vim.fn.input(prompt .. ": ")
		if value and value ~= "" then
			cb(value)
		end
	end
end

-- Find an existing instance for the given route whose origin_cwd matches the
-- current working directory.  Returns the instance or nil.
local function find_cwd_instance(instances, route, cwd)
	for _, inst in ipairs(instances) do
		if inst.target == route and inst.origin_cwd == cwd then
			return inst
		end
	end
	return nil
end

local function ensure_route_instance(route)
	if not route or route == "" then
		return false
	end
	local backend = get_backend()
	if not backend or not backend.state then
		return false
	end
	local st = backend.state.get()
	local cwd = vim.fn.getcwd()
	if st and st.instances then
		local existing = find_cwd_instance(st.instances, route, cwd)
		if existing then
			-- Reuse the existing instance — update last-used so sends go here
			local tmux_state = require("wiremux.backend.tmux.state")
			local batch = {}
			tmux_state.update_last_used(batch, existing.id)
			require("wiremux.backend.tmux.client").execute(batch)
			return true
		end
	end
	local wiremux = ensure_wiremux()
	if not wiremux then
		return false
	end
	wiremux.create({ target = route, behavior = "last", focus = true })
	return true
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
			local marker = item.name == state.current_route and "* " or "  "
			return marker .. item.label
		end,
	}, function(item)
		if not item then
			return
		end
		set_current_route(item.name)
		vim.notify(string.format("Wiremux route switched to %s", item.label), vim.log.levels.INFO)
	end)
end

local function pick_prompt()
	with_snacks_picker({
		items = state.options.prompts or default_prompts,
		prompt = "Wiremux Prompts",
		format_item = function(item)
			return item.label or item.value
		end,
	}, function(item)
		if item and item.value then
			send_via_wiremux(item.value)
		end
	end)
end

local function prompt_input(include_selection)
	local question = include_selection and "Wiremux prompt (selection)" or "Wiremux prompt"
	with_snacks_input(question, function(value)
		local text = vim.trim(value)
		if text == "" then
			return
		end
		if include_selection then
			text = text .. "\n\n{selection}"
		end
		send_via_wiremux(text)
	end)
end

function M.get_keymaps()
	return {
		normal = {
			{ "<leader>O", group = "Wiremux" },
			{ "<leader>Oo", M.toggle_target, desc = "(a)gent toggle" },
			{ "<leader>O?", function()
				prompt_input(false)
			end, desc = "(?) prompt" },
			{ "<leader>OP", pick_prompt, desc = "(P)rompt library" },
			{ "<leader>OS", M.select_route, desc = "(S)elect route" },
			{ "<leader>Ox", M.close_target, desc = "close target" },
		},
		visual = {
			{ "<leader>O", group = "Wiremux" },
			{ "<leader>Oa", function()
				M.send_selection()
			end, desc = "(a)sk selection" },
			{ "<leader>O?", function()
				prompt_input(true)
			end, desc = "(?) prompt selection" },
		},
		shared = {},
	}
end

return M
