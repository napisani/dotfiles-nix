local M = {}

function M.setup()
	local ok, codecompanion = pcall(require, "codecompanion")
	if not ok then
		vim.notify("codecompanion not found", vim.log.levels.ERROR)
		return
	end

	local project_utils = require("user.utils.project_utils")
	local proj_conf = project_utils.get_project_config().codecompanion or {}

	local prompt_library = proj_conf.prompt_library or {}

	codecompanion.setup({
		display = {
			diff = {
				enabled = true,
				provider = "split",
			},
		},

		adapters = {
			http = {
				opts = {
					show_model_choices = true,
				},
				copilot = function()
					return require("codecompanion.adapters").extend("copilot", {
						schema = {
							model = {
								default = "claude-sonnet-4",
							},
						},
					})
				end,
				openai = function()
					return require("codecompanion.adapters").extend("openai", {
						schema = {
							model = {
								default = "gpt-4.1-mini",
								choices = {
									"gpt-4.1-mini",
									"gpt-4.1",
									"gpt-4o",
									"gpt-4o-mini",
								},
							},
						},
					})
				end,
				openai_responses = function()
					return require("codecompanion.adapters").extend("openai_responses", {
						schema = {
							model = {
								default = "gpt-5.1-codex",
								choices = {
									"gpt-5.1-codex",
									"gpt-5.1",
									"gpt-4.1",
									"gpt-4o",
								},
							},
						},
						available_tools = {
							web_search = {
								enabled = function(_)
									return false
								end,
							},
						},
					})
				end,
				githubmodels = function()
					return require("codecompanion.adapters").extend("githubmodels", {
						schema = {
							model = {
								default = "gpt-4.1",
								choices = {
									"gpt-4.1",
									"gpt-4.1-mini",
									"claude-3.5-sonnet",
									"github-copilot/claude-sonnet-4.5",
									"github-copilot/claude-opus-4.5",
								},
							},
						},
					})
				end,

				gemini = function()
					return require("codecompanion.adapters").extend("gemini", {
						env = {
							api_key = "GEMINI_API_KEY",
						},
					})
				end,
			},
			acp = {
				opts = {
					show_presets = false,
				},
				opencode = function()
					return require("codecompanion.adapters").extend("opencode", {
						commands = {
							default = { "opencode", "acp" },
							copilot_sonnet_4_5 = {
								"opencode",
								"acp",
								"-m",
								"github-copilot/claude-sonnet-4.5",
							},
							copilot_opus_4_5 = {
								"opencode",
								"acp",
								"-m",
								"github-copilot/claude-opus-4.5",
							},
							anthropic_sonnet_4_5 = {
								"opencode",
								"acp",
								"-m",
								"anthropic/claude-sonnet-4.5",
							},
							anthropic_opus_4_5 = {
								"opencode",
								"acp",
								"-m",
								"anthropic/claude-opus-4.5",
							},
						},
					})
				end,
			},
		},

		interactions = {
			cmd = { adapter = "githubmodels" },
			inline = {
				adapter = {
					name = "openai",
					model = "gpt-4.1-mini",
				},
				keymaps = {
					accept_change = {
						modes = { n = "<leader>ma" },
					},
					reject_change = {
						modes = { n = "<leader>mr" },
					},
				},
			},
			chat = {
				adapter = {
					name = "openai_responses",
					model = "gpt-5.1-codex",
				},

				keymaps = {
					send = {
						modes = { n = { "<CR>", "<C-g>" }, i = "<C-g>" },
					},

					next_chat = {
						modes = { n = "]c" },
					},
					previous_chat = {
						modes = { n = "[c" },
					},
					change_adapter = {
						modes = { n = "<leader>aw" },
					},
					change_model = {
						modes = { n = "<leader>aW" },
						description = "Change model",
						callback = function(chat)
							local change_adapter = require("codecompanion.interactions.chat.keymaps.change_adapter")
							if chat.adapter.type == "http" then
								change_adapter.select_model(chat)
							elseif chat.adapter.type == "acp" then
								change_adapter.select_command(chat)
							else
								require("codecompanion.utils").notify(
									"Current adapter does not support model selection",
									vim.log.levels.WARN
								)
							end
						end,
					},
				},
			},
		},
		prompt_library = vim.tbl_extend("force", {}, prompt_library),
	})
end

function M.get_keymaps()
	local Snacks = require("snacks")
	local snacks_find_files = require("user.snacks.find_files")
	local snacks_git_files = require("user.snacks.git_files")
	local snacks_ai_context = require("user.snacks.ai_context_files")
	local ai_actions = require("user.snacks.ai_actions")

	return {
		normal = {
			{ "<leader>a", group = "(a)i" },
			{ "<leader>aa", "<cmd>:CodeCompanionChat<cr>", desc = "(a)dd to chat" },
			{ "<leader>aA", "<cmd>:CodeCompanionActions<cr>", desc = "(A)ctions" },
			{
				"<leader>a?",
				function()
					ai_actions.prompt_with_context({ mode = "n", prompt_label = "Ask AI", ai_mode = "plan" })
				end,
				desc = "(?) ask",
			},
			{
				"<leader>ae",
				function()
					ai_actions.prompt_with_context({ mode = "n", prompt_label = "Edit AI", ai_mode = "build" })
				end,
				desc = "(e)dit AI",
			},
			{ "<leader>ao", "<cmd>:CodeCompanionChat Toggle<cr>", desc = "(o)pen existing chat" },

			{ "<leader>aq", "<cmd>:CodeCompanionChat Toggle<cr>", desc = "(q)uit chat" },
			{ "<leader>aw", desc = "s(w)itch adapter" },
			{ "<leader>aW", desc = "s(W)itch model" },

			{ "<leader>af", group = "(f)ind context" },

			{
				"<leader>afd",
				function()
					snacks_ai_context.add_file_to_chat(snacks_git_files.git_changed_files)
				end,
				desc = "(d)iff git files",
			},

			{
				"<leader>afe",
				function()
					snacks_ai_context.add_file_to_chat(function(opts)
						return Snacks.picker.buffers(opts)
					end)
				end,
				desc = "Buffers",
			},

			{
				"<leader>afD",
				function()
					snacks_ai_context.add_file_to_chat(snacks_git_files.git_changed_cmp_base_branch)
				end,
				desc = "diff git (D)iff",
			},

			{
				"<leader>afC",
				function()
					snacks_ai_context.add_file_to_chat(snacks_git_files.git_conflicted_files)
				end,
				desc = "(C)onflicted files",
			},

			{
				"<leader>afr",
				function()
					snacks_ai_context.add_file_to_chat(snacks_find_files.find_files_from_root)
				end,
				desc = "files from (r)oot",
			},

			{
				"<leader>aft",
				function()
					snacks_ai_context.add_file_to_chat(function(opts)
						return Snacks.picker.git_files(opts)
					end)
				end,
				desc = "gi(t) files",
			},
			{
				"<leader>afp",
				function()
					snacks_ai_context.add_file_to_chat(snacks_find_files.find_path_files)
				end,
				desc = "(p)ath files",
			},
			{
				"<leader>aff",
				function()
					snacks_ai_context.add_current_buffer_to_chat()
				end,
				desc = "(f)ile current",
			},
		},

		visual = {
			{ "<leader>a", group = "(a)i" },
			{ "<leader>aa", ":<C-u>'<,'>CodeCompanionChat Add<cr>", desc = "(c)reate new chat" },
			{ "<leader>aA", ":<C-u>'<,'>CodeCompanionActions<cr>", desc = "(A)ctions" },
			{
				"<leader>a?",
				function()
					ai_actions.prompt_with_context({ mode = "v", prompt_label = "Ask AI (selection)", ai_mode = "plan" })
				end,
				desc = "(?) ask selection",
			},
			{
				"<leader>ae",
				function()
					ai_actions.prompt_with_context({ mode = "v", prompt_label = "Edit (selection)", ai_mode = "build" })
				end,
				desc = "(e)dit AI (selection)",
			},
			{ "<leader>ao", ":<C-u>'<,'>CodeCompanionChat Add<cr>", desc = "(o)pen existing chat" },
			{ "<leader>aq", ":<C-u>'<,'>CodeCompanionChat Toggle<cr>", desc = "(q)uit chat" },

			{ "<leader>ar", group = "(r)run" },
		},

		shared = {},
	}
end

return M
