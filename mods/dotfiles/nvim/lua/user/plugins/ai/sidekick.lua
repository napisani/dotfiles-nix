local M = {}

local function notify_missing(module_name)
	vim.notify_once(string.format("sidekick: %s not available", module_name), vim.log.levels.WARN)
end

M.opts = {
	nes = {
		enabled = false,
		debug = true,
	},
	cli = {
		watch = true,
		win = {
			layout = "right",
			split = {
				width = 80,
				height = 20,
			},
		},
		mux = {
			enabled = false,
			backend = "tmux",
		},
		tools = {
			opencode = { cmd = { "opencode" }, url = "https://github.com/sst/opencode" },
			cursor = { cmd = { "cursor-agent" }, url = "https://cursor.com/cli" },
			copilot = { cmd = { "copilot", "--banner" }, url = "https://github.com/github/copilot-cli" },
			claude = { cmd = { "claude" }, url = "https://github.com/anthropics/claude-code" },
		},
	},
	copilot = {
		status = {
			enabled = false,
		},
	},
	debug = true,
}

function M.setup(user_opts)
	local ok, sidekick = pcall(require, "sidekick")
	if not ok then
		vim.notify("sidekick.nvim not found", vim.log.levels.ERROR)
		return
	end

	local opts = vim.tbl_deep_extend("force", {}, M.opts, user_opts or {})
	sidekick.setup(opts)
end

local function require_cli(method)
	return function()
		local ok, cli = pcall(require, "sidekick.cli")
		if not ok then
			notify_missing("sidekick.cli")
			return
		end
		method(cli)
	end
end

local function require_sidekick(method)
	return function()
		local ok, sidekick = pcall(require, "sidekick")
		if not ok then
			notify_missing("sidekick")
			return
		end
		method(sidekick)
	end
end

local function require_nes(method)
	return function()
		local ok, nes = pcall(require, "sidekick.nes")
		if not ok then
			notify_missing("sidekick.nes")
			return
		end
		method(nes)
	end
end

function M.get_keymaps()
	return {
		normal = {
			{ "<leader>O", group = "Sidekick" },
			{
				"<leader>Oo",
				require_cli(function(cli)
					cli.toggle({ name = "opencode", focus = true })
				end),
				desc = "(a)gent toggle",
			},
			{
				"<leader>O?",
				require_cli(function(cli)
					cli.prompt()
				end),
				desc = "(?) prompt",
			},
			{
				"<leader>OS",
				require_cli(function(cli)
					cli.select()
				end),
				desc = "(S)elect CLI",
			},
			{
				"<leader>OP",
				require_cli(function(cli)
					if cli.select_prompt then
						cli.select_prompt()
					else
						cli.prompt()
					end
				end),
				desc = "(P)rompt picker",
			},
			{
				"<leader>ON",
				require_nes(function(nes)
					nes.update()
				end),
				desc = "(N)ES request",
			},
			{
				"<leader>Oj",
				require_sidekick(function(sidekick)
					sidekick.nes_jump_or_apply()
				end),
				desc = "(j)ump/apply NES",
			},
			{
				"<leader>Oe",
				require_nes(function(nes)
					nes.apply()
				end),
				desc = "(e)dit apply",
			},
			{
				"<leader>Ox",
				require_sidekick(function(sidekick)
					sidekick.clear()
				end),
				desc = "clear suggestions",
			},
		},
		visual = {
			{ "<leader>O", group = "Sidekick" },
			{
				"<leader>Oa",
				require_cli(function(cli)
					cli.send({ selection = true, submit = true })
				end),
				desc = "(a)sk selection",
			},
			{
				"<leader>O?",
				require_cli(function(cli)
					cli.prompt({ selection = true })
				end),
				desc = "(?) prompt selection",
			},
		},
		shared = {},
	}
end

return M
