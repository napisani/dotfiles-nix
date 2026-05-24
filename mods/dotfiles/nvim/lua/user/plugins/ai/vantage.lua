local M = {}

local function get_vantage()
	local ok, vantage = pcall(require, "vantage")
	if not ok then
		vim.notify("vantage.nvim not found", vim.log.levels.WARN)
		return nil
	end

	return vantage
end

function M.setup()
	local vantage = get_vantage()
	if not vantage then
		return
	end

	vantage.setup({
		provider = {
			name = "pi",
			pi = {
				provider = "openai",
				model = "gpt-4o-mini",
			},
		},
	})
end

function M.set_lens()
	local vantage = get_vantage()
	if not vantage then
		return
	end

	local default_text = nil
	if type(vantage.get_lens) == "function" then
		local current_lens = vantage.get_lens()
		if type(current_lens) == "table" and type(current_lens.text) == "string" then
			default_text = current_lens.text
		end
	end

	vim.ui.input({ prompt = "Lens: ", default = default_text }, function(text)
		if not text or text == "" then
			return
		end

		vantage.set_lens("learning", text)
		vim.notify("Vantage lens set: " .. text, vim.log.levels.INFO)
	end)
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
			{ "<leader>vl", M.set_lens, desc = "set lens" },
			{ "<leader>v?", "<cmd>VantageExplain<cr>", desc = "explain line" },
		},
		visual = {
			{ "<leader>va", ":VantageAnnotate<cr>", desc = "annotate selection" },
			{ "<leader>v?", ":VantageExplain<cr>", desc = "explain selection" },
		},
	}
end

return M
