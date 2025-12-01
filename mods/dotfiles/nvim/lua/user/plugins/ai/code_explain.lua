local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop

local default_config = {
	command_name = "CodeExplain",
	adapter = nil,
	window = {
		width_ratio = 0.5,
		height_ratio = 0.45,
		border = "rounded",
	},
	prompts = {
		system = table.concat({
			"You are an experienced engineer who writes concise and practical explanations.",
			"Highlight the high-level intent, the main steps, and any noteworthy edge cases.",
			"Respond using Markdown paragraphs and bullet lists when appropriate.",
		}, " "),
		user = table.concat({
			"Explain what this code is doing, why it might be structured this way,",
			"and mention any assumptions or potential pitfalls worth noting.",
		}, " "),
	},
}

local M = {
	config = default_config,
	_pending_requests = {},
}

local function get_request_state(bufnr)
	return M._pending_requests[bufnr]
end

local function clear_request_state(bufnr, request_id)
	local state = M._pending_requests[bufnr]
	if state and request_id and state.id ~= request_id then
		return
	end
	M._pending_requests[bufnr] = nil
end

local function cancel_request(bufnr, request_id)
	local state = M._pending_requests[bufnr]
	if not state or (request_id and state.id ~= request_id) then
		return
	end

	state.cancelled = true
	local handle = state.handle
	if handle then
		if type(handle.cancel) == "function" then
			pcall(handle.cancel, handle)
		elseif handle.shutdown then
			pcall(handle.shutdown, handle)
		end
	end
end

local function apply_buffer_defaults(bufnr)
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
	vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
end

local function create_window()
	local buf = api.nvim_create_buf(false, true)
	apply_buffer_defaults(buf)

	local width = math.max(60, math.floor(vim.o.columns * M.config.window.width_ratio))
	local height = math.max(16, math.floor(vim.o.lines * M.config.window.height_ratio))
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local win = api.nvim_open_win(buf, true, {
		relative = "editor",
		style = "minimal",
		row = row,
		col = col,
		width = width,
		height = height,
		border = M.config.window.border,
	})

	vim.api.nvim_set_option_value("wrap", true, { win = win })

	vim.keymap.set("n", "q", function()
		if api.nvim_win_is_valid(win) then
			api.nvim_win_close(win, true)
		end
	end, { buffer = buf, nowait = true, silent = true })

	vim.keymap.set("n", "<Esc>", function()
		if api.nvim_win_is_valid(win) then
			api.nvim_win_close(win, true)
		end
	end, { buffer = buf, nowait = true, silent = true })

	return buf, win
end

local function buffer_update(bufnr, lines)
	if not api.nvim_buf_is_valid(bufnr) then
		return
	end
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

local function cleanup_request(bufnr, request_id)
	clear_request_state(bufnr, request_id)
end

local function build_messages(context)
	local ok, cc_config = pcall(require, "codecompanion.config")
	if not ok then
		return nil, "CodeCompanion config unavailable"
	end

	local system_message = M.config.prompts.system
	local code_block = string.format(
		"File: %s\nFiletype: %s\nLines: %d-%d of %d (cursor at %d)\n\n```%s\n%s\n```",
		context.filename,
		context.filetype,
		context.start_line,
		context.end_line,
		context.total_lines,
		context.cursor_line,
		context.filetype,
		context.text
	)

	local user_message = table.concat({ code_block, "", M.config.prompts.user }, "\n")

	return {
		{
			role = cc_config.constants.SYSTEM_ROLE,
			content = system_message,
		},
		{
			role = cc_config.constants.USER_ROLE,
			content = user_message,
		},
	}
end

local function extract_context(range)
	local bufnr = api.nvim_get_current_buf()
	local total_lines = api.nvim_buf_line_count(bufnr)
	local start_line = (range and range.line1) or 1
	local end_line = (range and range.line2) or total_lines

	start_line = math.max(1, math.min(start_line, total_lines))
	end_line = math.max(start_line, math.min(end_line, total_lines))

	local lines = api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
	local text = table.concat(lines, "\n")

	return {
		text = text,
		filetype = vim.bo[bufnr].filetype ~= "" and vim.bo[bufnr].filetype or "text",
		filepath = api.nvim_buf_get_name(bufnr),
		filename = fn.fnamemodify(api.nvim_buf_get_name(bufnr), ":.") ~= ""
				and fn.fnamemodify(api.nvim_buf_get_name(bufnr), ":.")
			or "[No Name]",
		start_line = start_line,
		end_line = end_line,
		total_lines = total_lines,
		cursor_line = api.nvim_win_get_cursor(0)[1],
	}
end

local function normalize_content(content)
	if type(content) == "string" then
		return vim.split(content, "\n", { plain = true })
	end

	if type(content) == "table" then
		local parts = {}
		for _, chunk in ipairs(content) do
			if type(chunk) == "string" then
				table.insert(parts, chunk)
			elseif type(chunk) == "table" and chunk.text then
				table.insert(parts, chunk.text)
			elseif type(chunk) == "table" and chunk.content then
				table.insert(parts, chunk.content)
			end
		end
		return vim.split(table.concat(parts, ""), "\n", { plain = true })
	end

	return { "(no content received)" }
end

local function start_request(bufnr, context)
	local ok_http, http_client = pcall(require, "codecompanion.http")
	local ok_adapters, adapters = pcall(require, "codecompanion.adapters")
	local ok_config, cc_config = pcall(require, "codecompanion.config")

	if not (ok_http and ok_adapters and ok_config) then
		buffer_update(bufnr, { "CodeCompanion is not available in this Neovim session." })
		return
	end

	local adapter_source = M.config.adapter or cc_config.strategies.chat.adapter or cc_config.strategies.cmd.adapter
	local resolved_adapter = adapters.resolve(adapter_source)

	if not resolved_adapter then
		buffer_update(bufnr, { "Failed to resolve a CodeCompanion adapter." })
		return
	end

	resolved_adapter:map_schema_to_params()
	resolved_adapter.opts = vim.tbl_deep_extend("force", resolved_adapter.opts or {}, { stream = false })

	local messages, err = build_messages(context)
	if not messages then
		buffer_update(bufnr, { err or "Unable to build request payload." })
		return
	end

	local payload = { messages = resolved_adapter:map_roles(messages) }

	buffer_update(bufnr, { "Requesting explanation from CodeCompanion..." })

	local request_id = uv.hrtime()

	local handle = http_client.new({ adapter = resolved_adapter }):request(payload, {
		callback = function(err_msg, data, active_adapter)
			local state = get_request_state(bufnr)
			if not state or state.id ~= request_id then
				return
			end
			local was_cancelled = state.cancelled

			if err_msg then
				if not was_cancelled then
					buffer_update(bufnr, {
						"CodeCompanion request failed:",
						tostring(err_msg.message or err_msg),
					})
				end
				cleanup_request(bufnr, request_id)
				return
			end

			if was_cancelled then
				cleanup_request(bufnr, request_id)
				return
			end

			local parsed = adapters.call_handler(active_adapter, "parse_chat", data)
			if not parsed or not parsed.output or not parsed.output.content then
				buffer_update(bufnr, { "Received an empty response from CodeCompanion." })
				cleanup_request(bufnr, request_id)
				return
			end

			local lines = normalize_content(parsed.output.content)
			buffer_update(bufnr, lines)
			cleanup_request(bufnr, request_id)
		end,
		done = function()
			cleanup_request(bufnr, request_id)
		end,
	}, {
		silent = true,
		strategy = "code_explain",
		bufnr = context.bufnr,
	})

	if handle then
		M._pending_requests[bufnr] = { handle = handle, cancelled = false, id = request_id }
		api.nvim_buf_attach(bufnr, false, {
			on_detach = function()
				cancel_request(bufnr, request_id)
			end,
		})
	end
end

function M.explain(range)
	local context = extract_context(range)
	if not context or context.text == "" then
		vim.notify("CodeExplain: nothing to explain in the current selection", vim.log.levels.WARN)
		return
	end

	local buf, _ = create_window()
	context.bufnr = buf
	start_request(buf, context)
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", {}, default_config, opts or {})

	api.nvim_create_user_command(M.config.command_name, function(cmd_opts)
		M.explain({
			line1 = cmd_opts.line1,
			line2 = cmd_opts.line2,
		})
	end, {
		range = "%",
		desc = "Explain the current buffer or selection using CodeCompanion",
	})
end

return M
