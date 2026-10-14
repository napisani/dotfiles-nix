local M = {}
local api = vim.api
local registry = require("user.lsp.registry")
local servers = {}
local mode
local deferred = {}
local sleeping = {}
local pending
local start_timeout_ms = 60000

local function cancel_request(message, level)
	if pending then
		pending.timer:stop()
		pending.timer:close()
		pending = nil
		if message then
			vim.notify(message, level or vim.log.levels.INFO)
		end
	end
end

local function matching_servers(buf)
	if vim.bo[buf].buftype ~= "" or api.nvim_buf_get_name(buf) == "" or vim.b[buf].vantage_prompt_buffer then
		return {}
	end
	local matches = {}
	for _, name in ipairs(servers) do
		if vim.tbl_contains(vim.lsp.config[name].filetypes or {}, vim.bo[buf].filetype) then
			table.insert(matches, name)
		end
	end
	return matches
end

local function start_for_buffer(buf, retry)
	if mode == "off" then
		return
	end
	local starting = {}
	for _, name in ipairs(matching_servers(buf)) do
		if deferred[name] or sleeping[name] or (retry and vim.lsp.is_enabled(name)) then
			deferred[name] = nil
			sleeping[name] = nil
			table.insert(starting, name)
		end
	end
	if #starting > 0 then
		mode = "authoring"
		vim.lsp.enable(starting)
	end
end

-- Native disable can miss initializing clients whose source buffer closes
-- before LspAttach; the on_init guard must also enforce the current policy.
local function stop_unwanted_client(client)
	if mode == "off" or deferred[client.name] or sleeping[client.name] or not vim.lsp.is_enabled(client.name) then
		vim.lsp.enable(client.name, false)
		if not client:is_stopped() then
			client:stop()
		end
	end
end

local function enable_all()
	cancel_request()
	mode = "authoring"
	deferred = {}
	sleeping = {}
	vim.lsp.enable(servers)
end

function M.toggle()
	cancel_request()
	if mode == "authoring" then
		mode = "off"
		sleeping = {}
		vim.lsp.enable(servers, false)
	else
		enable_all()
	end
	vim.notify("LSP mode: " .. mode)
end

function M.request(method, action)
	if not mode then
		return action()
	end
	cancel_request()
	if mode == "off" then
		vim.notify("LSPs are off; use <leader>lo to enable them")
		return
	end
	local buf = api.nvim_get_current_buf()
	local function ready()
		for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
			if not client:is_stopped() and client:supports_method(method, buf) then
				return true
			end
		end
		return false
	end
	if ready() then
		return action()
	end
	if #matching_servers(buf) == 0 then
		vim.notify("No configured LSP for this buffer", vim.log.levels.WARN)
		return
	end
	local win = api.nvim_get_current_win()
	local cursor = api.nvim_win_get_cursor(win)
	local tick = api.nvim_buf_get_changedtick(buf)
	local original_mode = api.nvim_get_mode().mode
	start_for_buffer(buf, true)
	local request = { timer = assert(vim.uv.new_timer()) }
	pending = request
	local deadline = vim.uv.now() + start_timeout_ms
	request.timer:start(
		0,
		25,
		vim.schedule_wrap(function()
			if pending ~= request then
				return
			end
			if
				not api.nvim_win_is_valid(win)
				or not api.nvim_buf_is_valid(buf)
				or api.nvim_get_current_win() ~= win
				or api.nvim_get_current_buf() ~= buf
				or api.nvim_buf_get_changedtick(buf) ~= tick
				or api.nvim_get_mode().mode ~= original_mode
				or not vim.deep_equal(api.nvim_win_get_cursor(win), cursor)
			then
				cancel_request("Cancelled stale LSP action")
			elseif ready() then
				cancel_request()
				action()
			elseif vim.uv.now() >= deadline then
				cancel_request("Timed out waiting for LSP support: " .. method, vim.log.levels.WARN)
			end
		end)
	)
end

function M.sleep()
	cancel_request()
	local stopping = {}
	for _, name in ipairs(servers) do
		if registry.heavy[name] and vim.lsp.is_enabled(name) then
			sleeping[name] = true
			table.insert(stopping, name)
		end
	end
	if #stopping > 0 then
		vim.lsp.enable(stopping, false)
	end
end

function M.wake()
	local waking = vim.tbl_keys(sleeping)
	sleeping = {}
	if mode ~= "off" and #waking > 0 then
		vim.lsp.enable(waking)
	end
end

function M.status()
	return {
		mode = mode or "unconfigured",
		sleeping = vim.fn.sort(vim.tbl_keys(sleeping)),
		deferred = vim.fn.sort(vim.tbl_keys(deferred)),
	}
end

function M.setup(opts)
	opts = opts or {}
	cancel_request()
	servers = opts.servers or registry.servers()
	start_timeout_ms = opts.start_timeout_ms or 60000
	assert(start_timeout_ms > 0, "LSP start_timeout_ms must be positive")
	mode = "lazy"
	deferred = {}
	sleeping = {}
	local enabled, disabled = {}, {}
	for _, name in ipairs(servers) do
		local config = vim.lsp.config[name]
		local callbacks = config.on_init
		callbacks = type(callbacks) == "table" and vim.list_extend({}, callbacks) or callbacks and { callbacks } or {}
		if not vim.tbl_contains(callbacks, stop_unwanted_client) then
			table.insert(callbacks, stop_unwanted_client)
		end
		local overrides = { on_init = callbacks }
		if config.exit_timeout == nil then
			overrides.exit_timeout = 1000
		end
		vim.lsp.config(name, overrides)
		if registry.heavy[name] then
			deferred[name] = true
			table.insert(disabled, name)
		else
			table.insert(enabled, name)
		end
	end
	local group = api.nvim_create_augroup("user_lsp_lifecycle", { clear = true })
	api.nvim_create_autocmd("InsertEnter", {
		group = group,
		callback = function(args)
			start_for_buffer(args.buf)
		end,
	})
	api.nvim_create_autocmd({ "FocusLost", "VimLeavePre" }, {
		group = group,
		callback = function()
			cancel_request()
		end,
	})
	local keymaps = require("user.lsp.keymaps")
	for key_mode, mappings in pairs({ n = keymaps.base, v = keymaps.base_visual, i = keymaps.base_insert }) do
		for _, mapping in ipairs(mappings) do
			if mapping.method then
				vim.keymap.set(key_mode, mapping.key, mapping.action, { desc = mapping.desc, silent = true })
			end
		end
	end
	local function map_server_actions(buf)
		for _, name in ipairs(matching_servers(buf)) do
			for _, mapping in ipairs(keymaps.per_server[name] or {}) do
				if mapping.method then
					vim.keymap.set(mapping.mode or "n", mapping.key, mapping.action, {
						buffer = buf,
						desc = mapping.desc,
						silent = true,
					})
				end
			end
		end
	end
	api.nvim_create_autocmd("FileType", {
		group = group,
		callback = function(args)
			map_server_actions(args.buf)
		end,
	})
	for _, buf in ipairs(api.nvim_list_bufs()) do
		if api.nvim_buf_is_loaded(buf) then
			map_server_actions(buf)
		end
	end
	if #disabled > 0 then
		vim.lsp.enable(disabled, false)
	end
	if #enabled > 0 then
		vim.lsp.enable(enabled)
	end
	vim.keymap.set("n", "<leader>lo", M.toggle, { desc = "Toggle all LSPs" })
	api.nvim_create_user_command("LspToggle", M.toggle, { force = true })
	api.nvim_create_user_command("LspEnable", enable_all, { force = true })
end

return M
