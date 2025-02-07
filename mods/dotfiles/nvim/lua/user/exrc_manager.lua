local M = {}


M.get_exrc = function()
	return _G.EXRC_M or {}
end

M.source_local_config = function()
	local exrc_file = ".nvim.lua"
	if vim.fn.filereadable(exrc_file) == 1 then
		vim.cmd("source " .. exrc_file)
	end
end

M.setup = function()
	local exrc = M.get_exrc()
	if exrc.setup then
		exrc.setup()
	end
end

return M
