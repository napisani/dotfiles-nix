local M = {}

function M.setup()
	local ok, codecompanion = pcall(require, "codecompanion")
	if not codecompanion then
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

		strategies = {
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

		extensions = {
			mcphub = {
				callback = "mcphub.extensions.codecompanion",
				opts = {
					-- MCP Tools
					make_tools = true, -- Make individual tools (@server__tool) and server groups (@server) from MCP servers
					show_server_tools_in_chat = true, -- Show individual tools in chat completion (when make_tools=true)
					add_mcp_prefix_to_tool_names = true, -- Add mcp__ prefix (e.g `@mcp__github`, `@mcp__neovim__list_issues`)
					show_result_in_chat = true, -- Show tool results directly in chat buffer
					format_tool = nil, -- function(tool_name:string, tool: CodeCompanion.Agent.Tool) : string Function to format tool names to show in the chat buffer
					-- MCP Resources
					make_vars = true, -- Convert MCP resources to #variables for prompts
					-- MCP Prompts
					make_slash_commands = true, -- Add MCP prompts as /slash commands
				},
			},
		},
	})
end

function M.get_keymaps()
	local Snacks = require("snacks")
	local snacks_find_files = require("user.snacks.find_files")
	local snacks_git_files = require("user.snacks.git_files")
	local snacks_ai_context = require("user.snacks.ai_context_files")

	return {
		normal = {
			{ "<leader>a", group = "(a)i" },
			{ "<leader>aa", "<cmd>:CodeCompanionChat<cr>", desc = "(a)dd to chat" },
			{ "<leader>aA", "<cmd>:CodeCompanionActions<cr>", desc = "(A)ctions" },
			{ "<leader>a?", "<cmd>:CodeCompanion<cr>", desc = "(?) ask" },
			{ "<leader>ae", "<cmd>:CodeCompanion<cr>", desc = "(I)nline / rewrite results" },
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
			{ "<leader>a?", ":<C-u>'<,'>CodeCompanion<cr>", desc = "(?) ask" },
			{ "<leader>ae", ":<C-u>'<,'>CodeCompanion<cr>", desc = "(I)nline / rewrite" },
			{ "<leader>ao", ":<C-u>'<,'>CodeCompanionChat Add<cr>", desc = "(o)pen existing chat" },
			{ "<leader>aq", ":<C-u>'<,'>CodeCompanionChat Toggle<cr>", desc = "(q)uit chat" },

			{ "<leader>ar", group = "(r)run" },
		},

		shared = {},
	}
end

return M
