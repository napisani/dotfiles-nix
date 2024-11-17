local overseer = require("overseer")
local utils = require("user.utils")

local function parse_procmux_yaml()
	local contents = utils.read_yaml_file("procmux.yaml")
	if not contents or not contents.procs then
		return {}
	end

	local yaml_tasks = {}
	for proc, _detail in pairs(contents.procs) do
		table.insert(yaml_tasks, {
			name = "procmux-start: " .. proc,
			builder = function()
				return {
					cmd = 'procmux signal-start --name "' .. proc .. '"',
					components = { "default" },
					cwd = utils.get_root_dir(),
				}
			end,
		})
	end

	table.insert(yaml_tasks, {
		name = "procmux-restart-running",
		builder = function()
			return {
				cmd = "procmux signal-restart-running",
				components = { "default" },
				cwd = utils.get_root_dir(),
			}
		end,
	})

	table.insert(yaml_tasks, {
		name = "procmux-stop-running",
		builder = function()
			return {
				cmd = "procmux signal-stop-running",
				components = { "default" },
				cwd = utils.get_root_dir(),
			}
		end,
	})

	return yaml_tasks
end

overseer.setup({})

local tasks = {}

vim.schedule(function()
	tasks = parse_procmux_yaml()

	for _, task in ipairs(tasks) do
		overseer.register_template(task)
	end
end)
