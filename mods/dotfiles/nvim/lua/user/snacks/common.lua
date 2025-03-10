local utils = require("user.utils")
local M = {}
function M.paste_to_picker(cb)
	-- Copy visual selection to register 4
	vim.cmd('normal! "4y')
	-- Get text from register 4
	local selected_text = vim.fn.getreg("4")
	local p = cb({ pattern = selected_text })
	-- p.input.filter.pattern = selected_text
	return p
end

return M
