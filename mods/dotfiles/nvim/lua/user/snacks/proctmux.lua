local Snacks = require("snacks")
local Job = require("plenary.job")
local utils = require("user.utils")

local function parse_procmux_yaml()
	local contents = utils.read_yaml_file("procmux.yaml")
	if not contents or not contents.procs then
		return {}
	end

	local commands = {}
	for proc, _detail in pairs(contents.procs) do
		table.insert(commands, {
			name = "procmux-start: " .. proc,
			text = "procmux-start: " .. proc,
			file = "procmux-start-" .. proc,
			cmd = 'procmux signal-start --name "' .. proc .. '"',
			cwd = utils.get_root_dir(),
		})
	end

	table.insert(commands, {
		name = "procmux-restart-running",
		text = "procmux-restart-running",
		file = "procmux-restart-running",
		cmd = "procmux signal-restart-running",
		cwd = utils.get_root_dir(),
	})

	table.insert(commands, {
		name = "procmux-stop-running",
		text = "procmux-stop-running",
		file = "procmux-stop-running",
		cmd = "procmux signal-stop-running",
		cwd = utils.get_root_dir(),
	})

	return commands
end

local function run_command_in_background(cmd, cwd, name)
	-- Split the command string into command and arguments
	local parts = vim.split(cmd, " ")
	local command = parts[1]
	local args = {}

	-- Extract the rest as arguments
	for i = 2, #parts do
		-- Handle quoted arguments by removing quotes
		local arg = parts[i]
		if arg:sub(1, 1) == '"' and arg:sub(-1) == '"' then
			arg = arg:sub(2, -2)
		end
		table.insert(args, arg)
	end

	-- Notify that the command has started
	vim.notify("Started command: " .. name, vim.log.levels.INFO)

	-- Use Plenary's Job to run the command asynchronously
	Job:new({
		command = command,
		args = args,
		cwd = cwd,
		on_exit = function(job, exit_code)
			local status = exit_code == 0 and "succeeded" or "failed"
			local level = exit_code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR

			-- Send notification when the command completes
			vim.schedule(function()
				vim.notify("Command " .. name .. " " .. status .. " (exit code: " .. exit_code .. ")", level)
			end)
		end,
	}):start()
end

local function show_procmux_commands()
	local commands = parse_procmux_yaml()

	if #commands == 0 then
		vim.notify("No procmux commands found in procmux.yaml", vim.log.levels.WARN)
		return
	end

	-- Using Snacks.picker to create a picker with the commands
	Snacks.picker.pick({
		items = commands,
		prompt = "Procmux Commands >",
		confirm = function(item)
			-- When an item is selected, run the command in background
			run_command_in_background(item.cmd, item.cwd, item.name)
		end,
	})
end

-- Setup command to show the procmux commands picker
vim.api.nvim_create_user_command("ProcmuxCommands", show_procmux_commands, {
	desc = "Show procmux commands",
})

-- Parse procmux.yaml on startup
vim.schedule(function()
	parse_procmux_yaml()
end)

M = {
	show_procmux_commands = show_procmux_commands,
}
return M
