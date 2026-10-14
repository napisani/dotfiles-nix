local M = {}
local timer
local focused = true
local lifecycle = require("user.lsp.lifecycle")
local deadline
local focus_revision = 0

function M.setup(opts)
	opts = opts or {}
	local timeout_ms = opts.timeout_ms or 15 * 60 * 1000
	local focus_probe_error
	assert(type(timeout_ms) == "number" and timeout_ms > 0, "idle timeout_ms must be positive")
	focus_revision = focus_revision + 1
	if timer then
		timer:stop()
		timer:close()
	end
	timer = assert(vim.uv.new_timer())
	local group = vim.api.nvim_create_augroup("user_idle", { clear = true })

	local function arm_timer()
		deadline = deadline or vim.uv.now() + timeout_ms
		timer:start(
			math.max(0, deadline - vim.uv.now()),
			0,
			vim.schedule_wrap(function()
				if not focused and deadline and vim.uv.now() >= deadline then
					lifecycle.sleep()
				end
			end)
		)
	end

	local function set_focused(value)
		focus_revision = focus_revision + 1
		if focused == value then
			return
		end
		focused = value
		local statusline = package.loaded["user.plugins.ui.lualine"]
		if statusline then
			statusline.set_focused(value)
		end
		if focused then
			deadline = nil
			timer:stop()
			lifecycle.wake()
		else
			deadline = vim.uv.now() + timeout_ms
			arm_timer()
		end
	end

	local function check_tmux_focus()
		if not vim.env.TMUX or not vim.env.TMUX_PANE then
			return
		end
		local revision = focus_revision
		local ok, err = pcall(
			vim.system,
			{ "tmux", "list-clients", "-F", "#{pane_id} #{client_flags}" },
			{
				text = true,
				timeout = 1000,
			},
			vim.schedule_wrap(function(result)
				if not timer or revision ~= focus_revision then
					return
				end
				if result.code ~= 0 then
					focus_probe_error = "tmux exited with code " .. result.code .. ": " .. vim.trim(result.stderr or "")
					return
				end
				focus_probe_error = nil
				for line in result.stdout:gmatch("[^\r\n]+") do
					local pane, flags = line:match("^(%%%d+)%s+(.*)$")
					if not pane then
						focus_probe_error = "Unexpected tmux client format"
						return
					end
					if pane == vim.env.TMUX_PANE and ("," .. flags .. ","):find(",focused,", 1, true) then
						set_focused(true)
						return
					end
				end
				set_focused(false)
			end)
		)
		if not ok then
			focus_probe_error = tostring(err)
		end
	end

	vim.api.nvim_create_autocmd("FocusLost", {
		group = group,
		callback = function()
			set_focused(false)
		end,
	})
	vim.api.nvim_create_autocmd("FocusGained", {
		group = group,
		callback = function()
			set_focused(true)
		end,
	})
	vim.api.nvim_create_autocmd("UIEnter", {
		group = group,
		callback = function()
			set_focused(true)
			check_tmux_focus()
		end,
	})
	vim.api.nvim_create_autocmd("UILeave", {
		group = group,
		callback = function()
			vim.schedule(function()
				if timer and #vim.api.nvim_list_uis() == 0 then
					set_focused(false)
				end
			end)
		end,
	})
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			deadline = nil
			timer:stop()
			timer:close()
			timer = nil
		end,
	})
	vim.api.nvim_create_user_command("IdleStatus", function()
		vim.print({
			focused = focused,
			lsp = lifecycle.status(),
			timeout_ms = timeout_ms,
			focus_probe_error = focus_probe_error,
		})
	end, { force = true, desc = "Show editor focus and LSP state" })
	if not focused then
		arm_timer()
	end
	if #vim.api.nvim_list_uis() > 0 then
		check_tmux_focus()
	end
end

return M
