local common = require("user.snacks.ai_actions.common")
local agentic_actions = require("user.snacks.ai_actions.agentic")

local configured = false

local M = {}

-- agentic.nvim has no fullscreen API; sidebar width comes from `Config.windows.width` when the
-- layout opens (see agentic.ui.widget_layout). Toggle zoom by mutating Config and re-opening the
-- widget (same idea as `ChatWidget:rotate_layout`).
local AGENTIC_WIDTH_NORMAL = "40%"
local AGENTIC_WIDTH_ZOOM = "88%"
local agentic_zoomed = false

-- agentic.nvim uses vim.fn.executable on `command` (see agentic.acp.acp_health).
-- npmx installs @agentclientprotocol/claude-agent-acp and @zed-industries/codex-acp into
-- ~/.local/bin. If those symlinks are missing, :checkhealth stays red — run `home-manager
-- switch` and watch installNpmxTools for npm errors (previously `|| true` hid failures).
local function prepend_path(dir)
	dir = vim.fn.expand(dir)
	if vim.fn.isdirectory(dir) == 0 then
		return
	end
	local p = vim.env.PATH or ""
	if vim.startswith(p, dir .. ":") or p == dir then
		return
	end
	vim.env.PATH = dir .. ":" .. p
end

--- Ensure GUI Neovim can run Node-based global CLIs (shebang `env node`) and find bins.
local function ensure_acp_env_path()
	prepend_path("~/.local/bin")
	prepend_path("~/.nix-profile/bin")
	local user = vim.env.USER
	if user and user ~= "" then
		prepend_path("/etc/profiles/per-user/" .. user .. "/bin")
	end
end

--- Prefer ~/.local/bin (npmx); fall back to PATH after ensure_acp_env_path().
local function acp_command(name)
	local primary = vim.fn.expand("~/.local/bin/" .. name)
	if vim.fn.executable(primary) == 1 then
		return primary
	end
	local via_path = vim.fn.exepath(name)
	if via_path ~= "" and vim.fn.executable(via_path) == 1 then
		return via_path
	end
	return primary
end

--- Options passed to `require("agentic").setup(...)`.
local function get_agentic_opts()
	ensure_acp_env_path()
	return {
		-- Default session provider (brew `opencode` is usually on PATH; no extra path needed).
		-- Switch with <localleader>s in the widget: claude-agent-acp / codex-acp use ~/.local/bin above.
		provider = "opencode-acp",
		acp_providers = {
			["claude-agent-acp"] = {
				name = "Claude Agent ACP",
				command = acp_command("claude-agent-acp"),
				env = {},
			},
			["codex-acp"] = {
				name = "Codex ACP",
				command = acp_command("codex-acp"),
				env = {},
			},
			["gemini-acp"] = {
				name = "Gemini ACP",
				command = acp_command("gemini-acp"),
				env = {},
			},
		},

		windows = {
			position = "right",
			width = AGENTIC_WIDTH_NORMAL,
		},
		-- Match CodeCompanion-style submit; default Agentic uses <C-s> for submit.
		keymaps = {
			prompt = {
				submit = {
					"<CR>",
					{
						"<C-g>",
						mode = { "i", "n", "v" },
					},
				},
			},
		},
	}
end

local function with_agentic(fn)
	local ok, agentic = pcall(require, "agentic")
	if not ok then
		vim.notify("agentic not found", vim.log.levels.ERROR)
		return
	end

	fn(agentic)
end

--- Toggle between slim right sidebar (`AGENTIC_WIDTH_NORMAL`) and wide layout (`AGENTIC_WIDTH_ZOOM`).
function M.toggle_zoom()
	local ok, SessionRegistry = pcall(require, "agentic.session_registry")
	if not ok then
		vim.notify("agentic.session_registry not found", vim.log.levels.ERROR)
		return
	end

	local Config = require("agentic.config")

	SessionRegistry.get_session_for_tab_page(nil, function(session)
		if not session.widget:is_open() then
			vim.notify("Open Agentic first (<leader>oo)", vim.log.levels.INFO)
			return
		end

		agentic_zoomed = not agentic_zoomed
		Config.windows.width = agentic_zoomed and AGENTIC_WIDTH_ZOOM or AGENTIC_WIDTH_NORMAL

		local previous_mode = vim.fn.mode()
		local previous_buf = vim.api.nvim_get_current_buf()

		session.widget:hide()
		session.widget:show({ focus_prompt = false })

		vim.schedule(function()
			local win = vim.fn.bufwinid(previous_buf)
			if win ~= -1 then
				vim.api.nvim_set_current_win(win)
			end
			if previous_mode == "i" then
				vim.cmd("startinsert")
			end
		end)
	end)
end

function M.setup()
	local ok, agentic = pcall(require, "agentic")
	if not ok then
		vim.notify("agentic not found", vim.log.levels.ERROR)
		return
	end

	if configured then
		return
	end

	agentic.setup(get_agentic_opts())
	configured = true
end

local function stage_prompt(mode, prompt_label, ai_mode)
	local ctx = common.capture_context(mode)
	if not ctx then
		return
	end

	ctx.mode = ai_mode

	local ok_snacks, Snacks = pcall(require, "snacks")
	if not ok_snacks then
		vim.notify("Snacks not available", vim.log.levels.ERROR)
		return
	end

	Snacks.input({ prompt = prompt_label }, function(value)
		if not value or value == "" then
			return
		end
		agentic_actions.send_prompt_with_context(ctx, value)
	end)
end

function M.get_keymaps()
	return {
		normal = {
			{ "<leader>o", group = "(o)agentic" },
			{
				"<leader>oo",
				function()
					with_agentic(function(agentic)
						agentic.toggle({ auto_add_to_context = false })
					end)
				end,
				desc = "(o)pen toggle",
			},
			{
				"<leader>oq",
				function()
					with_agentic(function(agentic)
						agentic.close()
					end)
				end,
				desc = "(q)uit close",
			},
			{
				"<leader>on",
				function()
					with_agentic(function(agentic)
						agentic.new_session()
					end)
				end,
				desc = "(n)ew session",
			},
			{
				"<leader>os",
				function()
					with_agentic(function(agentic)
						agentic.restore_session()
					end)
				end,
				desc = "(s)ession restore",
			},
			{
				"<leader>ow",
				function()
					with_agentic(function(agentic)
						agentic.switch_provider()
					end)
				end,
				desc = "s(w)itch provider",
			},
			{
				"<leader>oz",
				function()
					M.toggle_zoom()
				end,
				desc = "(z)oom width toggle",
			},
			{
				"<leader>o?",
				function()
					stage_prompt("n", "Ask Agentic", "plan")
				end,
				desc = "(?) ask file",
			},
			{
				"<leader>oe",
				function()
					stage_prompt("n", "Agentic edit", "build")
				end,
				desc = "(e)dit file",
			},
		},
		visual = {
			{ "<leader>o", group = "(o)agentic" },
			{
				"<leader>oo",
				function()
					with_agentic(function(agentic)
						agentic.toggle({ auto_add_to_context = false })
					end)
				end,
				desc = "(o)pen toggle",
			},
			{
				"<leader>oq",
				function()
					with_agentic(function(agentic)
						agentic.close()
					end)
				end,
				desc = "(q)uit close",
			},
			{
				"<leader>oz",
				function()
					M.toggle_zoom()
				end,
				desc = "(z)oom width toggle",
			},
			{
				"<leader>o?",
				function()
					stage_prompt("v", "Ask Agentic", "plan")
				end,
				desc = "(?) ask selection",
			},
			{
				"<leader>oe",
				function()
					stage_prompt("v", "Agentic edit", "build")
				end,
				desc = "(e)dit selection",
			},
		},
		shared = {},
	}
end

return M
