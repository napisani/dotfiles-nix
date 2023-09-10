local conf = {
	hooks = {
		InspectPlugin = function(plugin, params)
			print(string.format("Plugin structure:\n%s", vim.inspect(plugin)))
			print(string.format("Command params:\n%s", vim.inspect(params)))
		end,

		-- GpImplement rewrites the provided selection/range based on comments in the code
		Implement = function(gp, params)
			local template = "Having following from {{filename}}:\n\n"
				.. "```{{filetype}}\n{{selection}}\n```\n\n"
				.. "Please rewrite this code according to the comment instructions."
				.. "\n\nRespond only with the snippet of finalized code:"

			gp.Prompt(
				params,
				gp.Target.rewrite,
				nil, -- command will run directly without any prompting for user input
				gp.config.command_model,
				template,
				gp.config.command_system_prompt
			)
		end,

    Explain = function(gp, params)
        local template = "I have the following code from {{filename}}:\n\n"
            .. "```{{filetype}}\n{{selection}}\n```\n\n"
            .. "Please respond by explaining the code above."
        gp.Prompt(params, gp.Target.popup, nil, gp.config.command_model,
            template, gp.config.chat_system_prompt)
    end,

    UnitTests = function(gp, params)
        local template = "I have the following code from {{filename}}:\n\n"
            .. "```{{filetype}}\n{{selection}}\n```\n\n"
            .. "Please respond by writing table driven unit tests for the code above."
        gp.Prompt(params, gp.Target.enew, nil, gp.config.command_model,
            template, gp.config.command_system_prompt)
    end,


	},
}

-- call setup on your config
require("gp").setup(conf)
