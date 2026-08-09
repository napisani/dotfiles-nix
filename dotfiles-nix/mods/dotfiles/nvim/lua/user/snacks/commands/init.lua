local utils = require("user.utils")
-- local whichkey_maps = require("user.whichkey.whichkey")

-- local keymappings = {}
-- local group = ""
-- for _, mapping in ipairs(whichkey_maps.mapping_n) do
-- 	if mapping.group ~= nil then
-- 		group = mapping.group .. " > "
-- 	else
-- 		table.insert(keymappings, vim.tbl_extend("force", mapping, { desc = group .. (mapping.desc or "") }))
-- 	end
-- end

local commands = utils.extend_lists(
	require("user.snacks.commands.package_manage").commands,
	require("user.snacks.commands.ai").commands,
	require("user.snacks.commands.lsp").commands,
	require("user.snacks.commands.project").commands,
	require("user.snacks.commands.finders").commands
)

local M = {}

function M.launch_command()
	local items = {}
	for _, command in ipairs(commands) do
		table.insert(items, {
			text = command.description,
			cmd = command[1],
		})
	end
	vim.ui.select(items, {
		prompt = "Launch Command",
		format_item = function(item)
			return item.text
		end,
	}, function(item)
		if item then
			if type(item.cmd) == "function" then
				item.cmd()
			else
				vim.cmd(item.cmd)
			end
		end
	end)
end
return M
