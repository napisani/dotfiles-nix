local file_utils = require("user.utils.file_utils")

local M = {}

local function find_sidekick_window()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		local ft = vim.bo[buf].filetype
		if ft == "sidekick_terminal" then
			return win, buf, ft
		end
	end
	return nil
end

function M.is_plugin_open()
	local ok = pcall(require, "sidekick.cli")
	if not ok then
		return false
	end
	return find_sidekick_window() ~= nil
end

function M.send_file(file_info, _opts)
	local ok_cli, cli = pcall(require, "sidekick.cli")
	if not ok_cli then
		vim.notify("sidekick.nvim not available", vim.log.levels.ERROR)
		return false
	end

	local ok_loc, loc = pcall(require, "sidekick.cli.context.location")
	if not ok_loc then
		vim.notify("sidekick location context not available", vim.log.levels.ERROR)
		return false
	end

	local ctx = {
		name = file_info.file_path,
		cwd = file_info.cwd or file_utils.get_root_dir(),
	}
	local text = loc.get(ctx, { kind = "file" })
	if not text or vim.tbl_isempty(text) then
		vim.notify("Could not render sidekick file context", vim.log.levels.WARN)
		return false
	end

	cli.send({ text = text, focus = false })
	return true
end

function M.send_text(text, _opts)
	if not text or text == "" then
		return false
	end
	local ok_cli, cli = pcall(require, "sidekick.cli")
	if not ok_cli then
		vim.notify("sidekick.nvim not available", vim.log.levels.ERROR)
		return false
	end

	cli.send({ msg = text, focus = false })
	return true
end

function M.open_convo_as_buffer()
	local ok_cli, cli = pcall(require, "sidekick.cli")
	if not ok_cli then
		vim.notify("sidekick.nvim not available", vim.log.levels.ERROR)
		return false
	end

	local win, buf = find_sidekick_window()
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		cli.show({ focus = false })
		win, buf = find_sidekick_window()
	end

	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		vim.notify("Sidekick terminal buffer is not available", vim.log.levels.ERROR)
		return false
	end

	vim.cmd("sbuffer " .. buf)
	return true
end

return M
