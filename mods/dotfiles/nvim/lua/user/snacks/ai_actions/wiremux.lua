local common = require("user.snacks.ai_actions.common")

local M = {}

local function normalize_reference_item(spec)
	if not spec then
		return nil
	end

	local kind = spec.kind or spec.type
	local relative_path = spec.relative_path or spec.path
	if not kind or not relative_path or relative_path == "" then
		return nil
	end

	return {
		kind = kind,
		relative_path = relative_path,
		start_line = spec.start_line,
		end_line = spec.end_line,
	}
end

local function format_reference_item(spec)
	spec = normalize_reference_item(spec)
	if not spec then
		return nil
	end

	if spec.kind == "file" then
		return "@" .. spec.relative_path
	end

	if spec.kind == "selection" and spec.start_line and spec.end_line then
		return string.format(
			"@%s lines %s-%s",
			spec.relative_path,
			spec.start_line,
			spec.end_line
		)
	end

	return nil
end

function M.format_reference_payload(spec)
	if not spec then
		return ""
	end

	local items = spec.items or { spec }
	local lines = {}
	for _, item in ipairs(items) do
		local line = format_reference_item(item)
		if line then
			table.insert(lines, line)
		end
	end

	if #lines == 0 then
		return ""
	end

	return table.concat(lines, "\n") .. "\n"
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
	if not ctx then
		return nil
	end
	local p = ctx.relative_path
		or (ctx.file_path and vim.fn.fnamemodify(ctx.file_path, ":."))
		or ""
	if p == "" or p == "." then
		return nil
	end
	if ctx.selection and ctx.start_line and ctx.end_line then
		return string.format("@%s lines %d-%d", p, ctx.start_line, ctx.end_line)
	end
	return "@" .. p
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
