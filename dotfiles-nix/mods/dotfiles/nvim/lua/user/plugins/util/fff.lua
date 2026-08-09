local M = {}

function M.setup()
	local ok, fff = pcall(require, "fff")
	if not ok then
		vim.notify("fff.nvim not found", vim.log.levels.WARN)
		return
	end

	fff.setup({
		lazy_sync = true, -- don't block startup on scanning

		grep = {
			smart_case = true,
			max_matches_per_file = 200,
			time_budget_ms = 150,
			modes = { "regex", "plain", "fuzzy" }, -- first mode is fff's native default
		},

		frecency = {
			enabled = true,
		},
	})
end

return M
