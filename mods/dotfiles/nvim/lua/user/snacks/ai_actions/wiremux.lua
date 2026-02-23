local M = {}

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
	return "@" .. relative
end

function M.is_plugin_open()
	return ensure_plugin() ~= nil
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

function M.open_convo_as_buffer()
	local plugin = ensure_plugin()
	if not plugin then
		return false
	end
	return plugin.focus_target()
end

return M
