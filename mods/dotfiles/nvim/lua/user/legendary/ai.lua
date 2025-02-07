local utils = require("user.utils")
local group = "Project > "
local commands = {}

local _cmds = utils.get_project_config().commands or {}
for _, value in ipairs(_cmds) do
	local cmd = value.command
	local desc = group .. value.description
	if cmd == nil or desc == nil then
		vim.notify("command and description are required for project commands", vim.log.levels.ERROR)
	else
		table.insert(commands, { cmd, description = desc })
	end
end

return {
	commands = commands,
}
