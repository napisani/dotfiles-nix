local M = {}

M.opts = {
	agent = {
		provider = "openai-codex",
		model = "gpt-5.4-mini",
		options = {
			reasoning = "minimal",
		},
	},
}

function M.setup()
	-- Vantage is configured lazily by the plugin spec when a :Vantage* command
	-- first loads vantage.nvim.
end

function M.configure(opts)
	local ok, vantage = pcall(require, "vantage")
	if not ok then
		vim.notify("vantage.nvim not found", vim.log.levels.WARN)
		return
	end

	vantage.setup(opts or M.opts)
end

function M.get_keymaps()
	return {
		shared = {
			{ "<leader>v", group = "Vantage" },
		},
		normal = {
			{ "<leader>va", "<cmd>VantageAnnotate<cr>", desc = "annotate line" },
			{ "<leader>vA", "<cmd>VantageAnnotate visible<cr>", desc = "annotate visible" },
			{ "<leader>vx", "<cmd>VantageAnnotationClear<cr>", desc = "clear annotations" },
			{ "<leader>vl", "<cmd>VantageSetLens learning<cr>", desc = "set lens" },
			{ "<leader>ve", "<cmd>VantageEdit<cr>", desc = "edit line" },
			{ "<leader>v?", "<cmd>VantageQuestion<cr>", desc = "ask question" },
		},
		visual = {
			{ "<leader>va", ":VantageAnnotate<cr>", desc = "annotate selection" },
			{ "<leader>ve", ":VantageEdit<cr>", desc = "edit selection" },
			{ "<leader>v?", ":VantageQuestion<cr>", desc = "ask about selection" },
		},
	}
end

return M
