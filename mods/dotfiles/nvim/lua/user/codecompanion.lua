local ok, codecompanion = pcall(require, "codecompanion")
if not codecompanion then
	vim.notify("codecompanion not found", vim.log.levels.ERROR)
	return
end

local project_utils = require("user._project_utils")
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
			copilot = function()
				return require("codecompanion.adapters").extend("copilot", {
					schema = {
						model = {
							default = "claude-3.7-sonnet",
						},
					},
				})
			end,

			gemini = function()
				return require("codecompanion.adapters").extend("gemini", {
					env = {
						api_key = "cmd: echo $GEMINI_API_KEY",
					},
				})
			end,
		},
	},

	strategies = {
		inline = {
			-- adapter = "openai",
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
			-- adapter = "anthropic",

			keymaps = {
				send = {
					modes = { n = { "<CR>", "<C-g>" }, i = "<C-g>" },
				},

				watch = {
					modes = { n = "gW" },
				},
				next_chat = {
					modes = { n = "]c" },
				},
				previous_chat = {
					modes = { n = "[c" },
				},

				debug = {
					modes = { n = "gD" },
					description = "Debug the current chat",
				},

				goto_file_under_cursor = {
					modes = { n = "gd" },
				},
				change_adapter = {
					modes = { n = "<leader>aw" },
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
