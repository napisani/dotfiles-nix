local dap = require("dap")
local utils = require("user.utils")
-- DAP python
-- you must first: `pip install debugpy` into you current venv

local function dap_root()
	return utils.get_dap_root()
end

dap.adapters.python = {
	type = "executable",
	-- command = 'path/to/virtualenvs/debugpy/bin/python';
	command = utils.python_path(),
	args = { "-m", "debugpy.adapter" },
}
dap.adapters.generic_remote = function(callback, config)
	local dap_conn_str = vim.fn.input("DAP server (empty cancels): ", "127.0.0.1:9001")

	if #dap_conn_str == 0 then
		print("DAP connection canceled.")
		return
	end

	local dap_host, dap_port
	local dap_conn_parts = vim.fn.split(dap_conn_str, ":", true)
	if #dap_conn_parts == 1 then
		dap_host = dap_conn_parts[1]
		dap_port = 9001
	elseif #dap_conn_parts == 2 then
		dap_host = dap_conn_parts[1]
		dap_port = dap_conn_parts[2]
	else
		vim.api.nvim_err_writeln("Invalid DAP server authority: " .. dap_conn_str)
		return
	end

	callback({
		type = "server",
		host = dap_host,
		port = dap_port,
	})

	print(string.format("Connected to: %s:%d", dap_host, dap_port))
end

dap.configurations.python = {
	{
		type = "generic_remote",
		name = "Generic remote",
		request = "attach",
		justMyCode = false,
		cwd = dap_root,
	},
	{
		type = "python",
		name = "Launch file - auto-detect python",
		request = "launch",
		program = "${file}",
		pythonPath = utils.python_path(),
		justMyCode = false,
		env = {
			PYTHONPATH = ".",
		}, -- Set the environment variables for the command
		cwd = dap_root,
	},
	{
		type = "python",
		name = "flask",
		pythonPath = utils.python_path(),
		request = "launch",
		module = "flask",
		justMyCode = false,
		args = {
			"run",
			"--no-debugger",
			"--no-reload",
		},
		env = {
			FLASK_DEBUG = "1",
		},
		cwd = dap_root,
	},

	{
		name = "dagster dev",
		type = "python",
		request = "launch",
		module = "dagster",
		args = {
			"dev",
			"-m",
			"example_repo",
			"-p",
			"3030",
		},
		subProcess = true,
		cwd = dap_root,
	},
}
