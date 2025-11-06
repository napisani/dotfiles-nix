return {
	preferred_picker = "snacks", -- 'telescope', 'fzf', 'mini.pick', 'snacks', if nil, it will use the best available picker. Note mini.pick does not support multiple selections
	preferred_completion = "blink", -- 'blink', 'nvim-cmp','vim_complete' if nil, it will use the best available completion
	default_global_keymaps = true, -- If false, disables all default global keymaps
	default_mode = "build", -- 'build' or 'plan' or any custom configured. @see [OpenCode Agents](https://opencode.ai/docs/modes/)
	keymap_prefix = "<leader>o", -- Default keymap prefix for global keymaps change to your preferred prefix and it will be applied to all keymaps starting with <leader>o
	keymap = {
		editor = {
			["<cr>"] = false,
			["<esc>"] = false,
			["<ESC>"] = false,
		},
		input_window = {
			["<C-g>"] = { "submit_input_prompt", mode = { "n", "i" } }, -- Submit prompt (normal mode and insert mode)
			["<leader>oq"] = { "close", mode = { "n" } }, -- Close UI windows
			["<leader>om"] = { "switch_mode", mode = { "n" } }, -- Switch between modes (build/plan)
			["<cr>"] = false,
			["<esc>"] = false,
			["<ESC>"] = false,
      -- clear tab too
      ["<tab>"] = false,
		},
		output_window = {
			["<leader>oq"] = { "close", mode = { "n" } }, -- Close UI windows
			["<esc>"] = false,
			["<ESC>"] = false,
      ["<tab>"] = false,
		},

		permission = {
			accept = "a", -- Accept permission request once (only available when there is a pending permission request)
			accept_all = "A", -- Accept all (for current tool) permission request once (only available when there is a pending permission request)
			deny = "r", -- Deny permission request once (only available when there is a pending permission request)
		},

		session_picker = {
			delete_session = { "<C-d>" }, -- Delete selected session in the session picker
		},
	},
}
