local ctx = {}
local M = {}

local utils = require("user.utils")

local write_context = function(name, content)
  local dir = utils.create_temp_directory("nvim-gp-ctx")
  local file = utils.join_path(dir, utils.file_safe_name(name) .. ".txt")
	vim.fn.writefile(content, file)
	ctx[name] = { file = file }

	return file
end

local delete_context = function(name)
	if name ~= nil and ctx[name] ~= nil then
		local file = ctx[name].file
		if file then
			if vim.fn.filereadable(file) == 1 then
				vim.fn.delete(file)
			end
		end
	end
	ctx[name] = nil
end

function M.name_context()
	local mode = vim.fn.mode()
	mode = mode:lower():sub(-#"v")
	local selection
	if mode == "v" then
		vim.cmd("normal! y")
		selection = utils.file_string_to_lines(vim.fn.getreg("0"))
	else
		selection = vim.fn.getline(1, "$")
	end
	local buf = vim.api.nvim_get_current_buf()
	local filetype = vim.api.nvim_buf_get_option(buf, "filetype")
	local filename = vim.fn.expand("%")
	local name = vim.fn.input("Enter the name of the context: ")
	delete_context(name)
	table.insert(selection, 1, "filecontent: ")
	table.insert(selection, 1, "filetype: " .. filetype)
	table.insert(selection, 1, "filename: " .. filename)
	table.insert(selection, 1, "```")
	table.insert(selection, "```")
	write_context(name, selection)
end

function M.clear_context()
	for k, v in pairs(ctx) do
		delete_context(k)
	end
	ctx = {}
end

function M.get_context_value(name)
	if name ~= nil and ctx[name] ~= nil then
		local file = ctx[name].file
		if file then
			if vim.fn.filereadable(file) == 1 then
				return vim.fn.readfile(file)
			end
		end
	end
	return nil
end

function apply_replacements(prompt)
	for k, v in pairs(ctx) do
		if k ~= nil and v ~= nil then
			prompt = prompt:gsub(k, "{{" .. k .. "}}")
		end
	end
	for k, v in pairs(ctx) do
		if k ~= nil and v ~= nil then
			local content = utils.read_file_to_string(v.file)
			prompt = prompt:gsub("{{" .. k .. "}}", content)
		end
	end
	return prompt
end

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
			gp.Prompt(params, gp.Target.popup, nil, gp.config.command_model, template, gp.config.chat_system_prompt)
		end,

		UnitTests = function(gp, params)
			local template = "I have the following code from {{filename}}:\n\n"
				.. "```{{filetype}}\n{{selection}}\n```\n\n"
				.. "Please respond by writing unit tests for the code above."
			gp.Prompt(params, gp.Target.enew, nil, gp.config.command_model, template, gp.config.command_system_prompt)
		end,

		UnitTestsWithContext = function(gp, params)
			local template = "Here is an example of an existing unit test suite:\n"
				.. "TEST\n"
				.. "Here is a code that needs to be unit tested:\n\n"
				.. "CODE\n"
				.. "Please respond by writing unit tests for the code above."
			template = apply_replacements(template)
			gp.Prompt(params, gp.Target.enew, nil, gp.config.command_model, template, gp.config.command_system_prompt)
		end,

		NameContext = function(_gp, _params)
			M.name_context()
		end,

		AskWithContext = function(gp, params)
			local system_prompt = gp.config.command_system_prompt
			local ctx_keys = {}
			for k, _ in pairs(ctx) do
				table.insert(ctx_keys, k)
			end
			local ctx_keys_str = table.concat(ctx_keys, ", ")
			local template = vim.fn.input("Enter AI Prompt context(" .. ctx_keys_str .. "): ")
			template = apply_replacements(template)
			template = system_prompt .. "\n" .. template .. "\n"
			gp.Prompt(params, gp.Target.enew, nil, gp.config.command_model, template, gp.config.command_system_prompt)
		end,
	},
}

-- call setup on your config
require("gp").setup(conf)
return M
