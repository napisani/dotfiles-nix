
return{
			opts = {
				-- add any options here
				cli = {
					mux = {
						backend = "tmux",
						enabled = true,
					},
				},
			},
			keys = {
				{
					"<tab>",
					function()
						-- if there is a next edit, jump to it, otherwise apply it if any
						if not require("sidekick").nes_jump_or_apply() then
							return "<Tab>" -- fallback to normal tab
						end
					end,
					expr = true,
					desc = "Goto/Apply Next Edit Suggestion",
				},
				{
					"<leader>oa",
					function()
						require("sidekick.cli").toggle()
					end,
					desc = "Sidekick Toggle CLI",
				},
				{
					"<leader>os",
					function()
						require("sidekick.cli").select()
					end,
					-- Or to select only installed tools:
					-- require("sidekick.cli").select({ filter = { installed = true } })
					desc = "Select CLI",
				},
				{
					"<leader>ot",
					function()
						require("sidekick.cli").send({ msg = "{this}" })
					end,
					mode = { "x", "n" },
					desc = "Send This",
				},
				{
					"<leader>ov",
					function()
						require("sidekick.cli").send({ msg = "{selection}" })
					end,
					mode = { "x" },
					desc = "Send Visual Selection",
				},
				{
					"<leader>op",
					function()
						require("sidekick.cli").prompt()
					end,
					mode = { "n", "x" },
					desc = "Sidekick Select Prompt",
				},
				{
					"<leader>ow",
					function()
						require("sidekick.cli").focus()
					end,
					mode = { "n", "x", "i", "t" },
					desc = "Sidekick Switch Focus",
				},
				-- Example of a keybinding to open Claude directly
				{
					"<leader>oc",
					function()
						require("sidekick.cli").toggle({ name = "claude", focus = true })
					end,
					desc = "Sidekick Toggle Claude",
				},
			},
		}
