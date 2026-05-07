local common = require("user.snacks.ai_actions.common")

local M = {}

function M.format_reference_payload(spec)
	return common.format_reference_payload(spec)
end

local function ensure_plugin()
	local ok, plugin = pcall(require, "user.plugins.ai.wiremux")
	if not ok then
		vim.notify("Wiremux plugin module not loaded", vim.log.levels.ERROR)
		return nil
	end
	return plugin
end

local function format_file_payload(file_info)
	local relative = file_info.relative_path or vim.fn.fnamemodify(file_info.file_path, ":.")
	if not relative or relative == "" then
		return nil
	end
	if file_info.start_line and file_info.end_line then
		return M.format_reference_payload({
			kind = "selection",
			relative_path = relative,
			start_line = file_info.start_line,
			end_line = file_info.end_line,
		})
	end
	return M.format_reference_payload({
		kind = "file",
		relative_path = relative,
	})
end

-- Returns true only when a wiremux instance for the current route and cwd exists.
-- This prevents the ai_actions dispatcher from routing to wiremux when there is
-- no running session for this project.
function M.is_plugin_open()
	local plugin = ensure_plugin()
	if not plugin or not plugin.is_available() then
		return false
	end
	local ok, backend = pcall(require, "wiremux.backend")
	if not ok then
		return false
	end
	local b = backend.get()
	if not b or not b.state then
		return false
	end
	local ok_st, st = pcall(b.state.get)
	if not ok_st or not st or not st.instances then
		return false
	end
	local route = plugin.get_current_route()
	local cwd = vim.fn.getcwd()
	for _, inst in ipairs(st.instances) do
		if inst.target == route and inst.origin_cwd == cwd then
			return true
		end
	end
	return false
end

function M.send_file(file_info, _opts)
	local plugin = ensure_plugin()
	if not plugin then
		return false
	end
	if not file_info or not file_info.file_path then
		return false
	end
	local payload = format_file_payload(file_info)
	if not payload then
		vim.notify("Unable to resolve file path for Wiremux reference", vim.log.levels.WARN)
		return false
	end
	return plugin.send_text(payload, { focus = true })
end

function M.send_reference_batch(items)
	local plugin = ensure_plugin()
	if not plugin then
		return false
	end
	local payload = M.format_reference_payload({ items = items })
	if payload == "" then
		return false
	end
	return plugin.send_text(payload, { focus = true })
end

---@param ctx { relative_path?: string, file_path?: string, selection?: string, start_line?: number, end_line?: number }|nil
function M.format_context_ref_line(ctx)
	return common.format_context_ref_line(ctx)
end

-- ctx: { file_path, relative_path, line, selection? } — same shape as common.capture_context
function M.send_prompt_with_context(ctx, prompt)
	local plugin = ensure_plugin()
	if not plugin or not ctx then
		return false
	end
	if not prompt or prompt == "" then
		return false
	end
	local ref = M.format_context_ref_line(ctx)
	if not ref then
		return false
	end
	local message = ref .. "\n\n" .. prompt
	return plugin.send_text(message, { focus = true })
end

function M.send_text(text, _opts)
	local plugin = ensure_plugin()
	if not plugin then
		return false
	end
	if not text or text == "" then
		return false
	end
	return plugin.send_text(text, { focus = true })
end

-- Stage context (file ref + selection) into the target pane without submitting.
function M.stage_context(ctx)
	local plugin = ensure_plugin()
	if not plugin then
		return false
	end

	local message = common.build_context_message(ctx, {
		style = common.REF_STYLE_AT,
	})
	if message == "" then
		return false
	end

	-- Send without submitting (submit = false is the default, but explicit here)
	return plugin.send_text(message, { focus = true, submit = false })
end

function M.open_convo_as_buffer()
	local plugin = ensure_plugin()
	if not plugin then
		return false
	end
	return plugin.focus_target()
end

return M
