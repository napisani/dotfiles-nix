---@diagnostic disable: undefined-global

local M = {}

local function in_tmux()
	return vim.env.TMUX ~= nil and vim.fn.executable("tmux") == 1
end

local function tmux_command(command)
	if not in_tmux() then
		return nil
	end

	local socket = vim.fn.split(vim.env.TMUX, ",")[1]
	if socket == nil or socket == "" then
		return nil
	end

	return vim.fn.system("tmux -S " .. vim.fn.shellescape(socket) .. " " .. command)
end

local function was_window_zoomed()
	local zoom_flag = tmux_command("display-message -p '#{window_zoomed_flag}'")
	return zoom_flag ~= nil and vim.trim(zoom_flag) == "1"
end

local nav_config = {
	Left = { vim = "h", tmux = "L" },
	Down = { vim = "j", tmux = "D" },
	Up = { vim = "k", tmux = "U" },
	Right = { vim = "l", tmux = "R" },
	LastActive = { vim = "p", tmux = "l" },
}

local function try_vim_navigate(vim_direction)
	local winnr_before = vim.fn.winnr()
	pcall(vim.cmd, "wincmd " .. vim_direction)
	return vim.fn.winnr() ~= winnr_before
end

local function tmux_navigate_preserve_zoom(tmux_direction)
	if not in_tmux() then
		return
	end

	tmux_command("select-pane -" .. tmux_direction .. " -Z")
end

local function tmux_move_and_zoom(direction)
	local cmd = "NvimTmuxNavigate" .. direction
	local window_was_zoomed = was_window_zoomed()
	local move_cfg = nav_config[direction]

	if window_was_zoomed and move_cfg ~= nil then
		local moved_in_vim = try_vim_navigate(move_cfg.vim)
		if not moved_in_vim then
			tmux_navigate_preserve_zoom(move_cfg.tmux)
		end
		return
	end

	if vim.fn.exists(":" .. cmd) == 2 then
		vim.cmd(cmd)
	else
		vim.notify("Command " .. cmd .. " not found. Check your plugin name!", vim.log.levels.ERROR)
	end
end

function M.setup()
	local status_ok, nvim_tmux_nav = pcall(require, "nvim-tmux-navigation")
	if not status_ok then
		return
	end

	nvim_tmux_nav.setup({
		disable_when_zoomed = false,
	})

	local opts = { noremap = true, silent = true }

	vim.keymap.set("n", "<C-h>", function()
		tmux_move_and_zoom("Left")
	end, opts)
	vim.keymap.set("n", "<C-j>", function()
		tmux_move_and_zoom("Down")
	end, opts)
	vim.keymap.set("n", "<C-k>", function()
		tmux_move_and_zoom("Up")
	end, opts)
	vim.keymap.set("n", "<C-l>", function()
		tmux_move_and_zoom("Right")
	end, opts)
	vim.keymap.set("n", "<C-\\>", function()
		tmux_move_and_zoom("LastActive")
	end, opts)
end

return M
