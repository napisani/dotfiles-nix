local M = {}

--[[

local project_config = {
	branches = {
		main = "develop",
		prod = "main",
	},
	debug = {
		launch_file = ".nvimlaunch.json",
	},
	autocmds = {
		{
			event = "BufWritePre",
			pattern = "*.go",
			command = "!procmux signal-start --name run-day",
		},
	},
	commands = {
		{
			command = "procmux signal-start --name run-day",
			description = "procmux signal start run day",
		},
	},
	lint = {
		"eslint",
		"prettier",
	},
}

_G.EXRC_M = {
	project_config = project_config,

	setup = function() end,
}

]]

M.get_exrc = function()
	return _G.EXRC_M or {}
end

M.source_local_config = function()
	local exrc_file = ".nvim.lua"
	if vim.fn.filereadable(exrc_file) == 1 then
		vim.cmd("source " .. exrc_file)
	end
end

M.setup = function()
	local exrc = M.get_exrc()
	if exrc.setup then
		exrc.setup()
	end
end

return M
