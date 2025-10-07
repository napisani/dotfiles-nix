local Snacks = require("snacks")
local Job = require("plenary.job")
local utils = require("user.utils")

local function parse_procmux_yaml()
	local contents = nil
	local filenames = {
		"procmux.yaml",
		"procmux.yml",
		"proctmux.yaml",
		"proctmux.yml",
	}
	for _, filename in ipairs(filenames) do
		contents = utils.read_yaml_file(utils.join_path(utils.get_root_dir(), filename))
		if contents then
			break
		end
		contents = utils.read_yaml_file(utils.join_path(vim.fn.getcwd(), filename))
		if contents then
			break
		end
	end

	if not contents or not contents.procs then
		return {}
	end

	local commands = {}
	for proc, _detail in pairs(contents.procs) do
		table.insert(commands, {
			name = "proctmux-start: " .. proc,
			text = "proctmux-start: " .. proc,
			file = "proctmux-start-" .. proc,
			cmd = 'proctmux signal-start --name "' .. proc .. '"',
			cwd = utils.get_root_dir(),
		})
	end

	table.insert(commands, {
		name = "protcmux-restart-running",
		text = "proctmux-restart-running",
		file = "proctmux-restart-running",
		cmd = "proctmux signal-restart-running",
		cwd = utils.get_root_dir(),
	})

	table.insert(commands, {
		name = "proctmux-stop-running",
		text = "proctmux-stop-running",
		file = "proctmux-stop-running",
		cmd = "proctmux signal-stop-running",
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
		prompt = "Proctmux CMD > ",
		confirm = function(_picker, item)
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
