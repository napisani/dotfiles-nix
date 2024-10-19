return {
	---@alias Provider "claude" | "openai" | "azure" | "gemini" | "cohere" | "copilot" | string
	provider = "claude", -- Recommend using Claude
	auto_suggestions_provider = "claude", -- Since auto-suggestions are a high-frequency operation and therefore expensive, it is recommended to specify an inexpensive provider or even a free provider: copilot
	behaviour = {
		auto_suggestions = false, -- Experimental stage
		auto_set_highlight_group = true,
		auto_set_keymaps = true,
		auto_apply_diff_after_generation = false,
		support_paste_from_clipboard = false,
	},
	mappings = {
		--- @class AvanteConflictMappings
		submit = {
			normal = "<CR>",
			insert = "<C-g><C-g>",
		},
	},
	hints = { enabled = false },
	additional_cmp_sources = {
		{ name = "context_nvim" },
	},
}
