local status_ok, gp = pcall(require, "gp")
if not status_ok then
	vim.notify("gp not found")
	return
end

local conf = require("gp.config")
conf.providers.copilot.disable = false
conf.providers.openai.disable = false
conf.providers.anthropic.disable = false

conf = vim.tbl_extend("force", conf, {
	hooks = {
		InspectPlugin = function(plugin, params)
			print(string.format("Plugin structure:\n%s", vim.inspect(plugin)))
			print(string.format("Command params:\n%s", vim.inspect(params)))
		end,

		Explain = function(gp, params)
			local template = "I have the following code from {{filename}}:\n\n"
				.. "```{{filetype}}\n{{selection}}\n```\n\n"
				.. "Please respond by explaining the code above."
			local agent = gp.get_command_agent()
			gp.Prompt(params, gp.Target.vnew, agent, template)
		end,

		UnitTests = function(gp, params)
			local template = "I have the following code from {{filename}}:\n\n"
				.. "```{{filetype}}\n{{selection}}\n```\n\n"
				.. "Please respond by writing unit tests for the code above."
			local agent = gp.get_command_agent()
			gp.Prompt(params, gp.Target.vnew, agent, template)
		end,
	},
})

-- -- call setup on your config
gp.setup(conf)

return M
