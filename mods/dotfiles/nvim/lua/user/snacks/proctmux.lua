local Snacks = require("snacks")
local Job = require("plenary.job")
local utils = require("user.utils")

local base_cmd = "./bin/proctmux"

-- Function to get process status from proctmux
local function get_process_status()
	local output = {}
	local success = false
	local job = Job:new({
		command = base_cmd,
		args = { "signal-list" },
		cwd = utils.get_root_dir(),
		on_stdout = function(_, line)
			table.insert(output, line)
		end,
		on_exit = function(_, exit_code)
			success = exit_code == 0
		end,
	})

	job:sync()

	if not success or #output < 2 then
		return {}
	end

	-- Parse the output into a table of process status
	local process_status = {}
	-- Skip the header line (NAME    STATUS)
	for i = 2, #output do
		local line = output[i]
		if line and line:match("%S") then
			local name, status = line:match("^(.-)%s+(%w+)%s*$")
			if name and status then
				-- Trim whitespace
				name = name:gsub("^%s*(.-)%s*$", "%1")
				process_status[name] = status
			end
		end
	end

	return process_status
end

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

	-- Get the current status of all processes
	local process_status = get_process_status()
	local commands = {}

	-- Add commands based on process status
	for proc, _ in pairs(contents.procs) do
		local status = process_status[proc] or "unknown"

		if status == "stopped" or status == "unknown" then
			-- Add start command for stopped processes
			table.insert(commands, {
				name = "proctmux-start: " .. proc,
				text = "proctmux-start: " .. proc,
				file = "proctmux-start-" .. proc,
				cmd = { base_cmd, "signal-start", proc },
				cwd = utils.get_root_dir(),
			})
		elseif status == "running" then
			-- Add stop command for running processes
			table.insert(commands, {
				name = "proctmux-stop: " .. proc,
				text = "proctmux-stop: " .. proc,
				file = "proctmux-stop-" .. proc,
				cmd = { base_cmd, "signal-stop", proc },
				cwd = utils.get_root_dir(),
			})

			-- Add restart command for running processes
			table.insert(commands, {
				name = "proctmux-restart: " .. proc,
				text = "proctmux-restart: " .. proc,
				file = "proctmux-restart-" .. proc,
				cmd = { base_cmd, "signal-restart", proc },
				cwd = utils.get_root_dir(),
			})
		end
	end

	-- Add global commands for managing all processes
	table.insert(commands, {
		name = "proctmux-restart-running",
		text = "proctmux-restart-running",
		file = "proctmux-restart-running",
		cmd = { base_cmd, "signal-restart-running" },
		cwd = utils.get_root_dir(),
	})

	table.insert(commands, {
		name = "proctmux-stop-running",
		text = "proctmux-stop-running",
		file = "proctmux-stop-running",
		cmd = { base_cmd, "signal-stop-running" },
		cwd = utils.get_root_dir(),
	})

	return commands
end

-- ... rest of the original file remains unchanged
local function run_command_in_background(cmd, cwd, name)
	-- cmd is now a table with the command as the first element and arguments as the rest
	local command = cmd[1]
	local args = {}

	-- Extract arguments from index 2 onwards
	for i = 2, #cmd do
		table.insert(args, cmd[i])
	end

	-- Create a string representation of the command for logging
	local cmd_str = command .. " " .. table.concat(args, " ")

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

local M = {
	show_procmux_commands = show_procmux_commands,
}
return M
