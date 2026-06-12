local M = {
	opts = {
		enabled = function()
			return true
		end,

		-- 'default' for mappings similar to built-in completion
		-- 'super-tab' for mappings similar to vscode (tab to accept, arrow keys to navigate)
		-- 'enter' for mappings similar to 'super-tab' but with 'enter' to accept
		-- See the full "keymap" documentation for information on defining your own keymap.
		keymap = {
			preset = "enter",
			-- ["<CR>"] = { "select_and_accept" },
		},

		completion = {
			list = {
				selection = {
					preselect = false,
				},
			},
		},

		appearance = {
			-- Sets the fallback highlight groups to nvim-cmp's highlight groups
			-- Useful for when your theme doesn't support blink.cmp
			-- Will be removed in a future release
			use_nvim_cmp_as_default = true,
			-- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
			-- Adjusts spacing to ensure icons are aligned
			nerd_font_variant = "mono",
		},

		-- Default list of enabled providers defined so that you can extend it
		-- elsewhere in your config, without redefining it, due to `opts_extend`
		sources = {
			default = { "lsp", "path", "buffer", "vantage_skills", "skills", "prompt_files" },
			per_filetype = {},
			providers = {
				vantage_skills = {
					name = "Vantage Skills",
					module = "vantage.integrations.blink_skills",
					async = true,
					min_keyword_length = 0,
					score_offset = 110,
					enabled = function()
						local ok, value = pcall(vim.api.nvim_buf_get_var, 0, "vantage_prompt_buffer")
						return ok and value == true
					end,
				},
				prompt_files = {
					name = "Prompt files",
					module = "user.completion.sources.prompt_files",
					min_keyword_length = 0,
					score_offset = 95,
					enabled = function()
						local ok, value = pcall(vim.api.nvim_buf_get_var, 0, "prompt_builder")
						return ok and value == true
					end,
				},
				skills = {
					name = "Skills",
					module = "user.completion.sources.skills",
					min_keyword_length = 0,
					score_offset = 100,
					enabled = function()
						local ok, value = pcall(vim.api.nvim_buf_get_var, 0, "prompt_builder")
						return ok and value == true
					end,
				},
			},
		},
	},
	opts_extend = { "sources.default" },
}

return M
