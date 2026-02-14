-- nvim-dap.lua
-- Debug Adapter Protocol (DAP) configuration with UI, virtual text, and language-specific debuggers

local M = {}

--- Setup function for nvim-dap
-- Configures DAP, DAP UI, virtual text, and loads language-specific debuggers
function M.setup()
	local dap_status_ok, dap = pcall(require, "dap")
	if not dap_status_ok then
		vim.notify("nvim-dap not found")
		return
	end

	local dap_ui_status_ok, dapui = pcall(require, "dapui")
	if not dap_ui_status_ok then
		vim.notify("nvim-dap-ui not found")
		return
	end


	-- # DAP Virtual Text
	local dap_virtual_text_status_ok, dap_virtual_text = pcall(require, "nvim-dap-virtual-text")
	if dap_virtual_text_status_ok then
		dap_virtual_text.setup({})
	end

	dapui.setup({})

	-- Auto-open/close DAP UI on debug session events
	dap.listeners.before.attach["dapui_config"] = function()
		dapui.open({})
	end
	dap.listeners.before.launch["dapui_config"] = function()
		dapui.open({})
	end
	dap.listeners.before.event_terminated["dapui_config"] = function()
		dapui.close({})
	end
	dap.listeners.before.event_exited["dapui_config"] = function()
		dapui.close({})
	end

	-- Load language-specific debugger configurations
	require("user.dap.typescript")
	require("user.dap.python")
	require("user.dap.go")

end

--- Get keymaps for nvim-dap
-- @return table with shared, normal, and visual mode keymaps
function M.get_keymaps()
	return {
		shared = {},
		normal = {
			{
				"<leader>dB",
				"<Cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>",
				desc = "conditional breakpoint",
			},
			{
				"<leader>dL",
				"<Cmd>lua require'dap'.set_breakpoint(vim.fn.input(nil, nil, vim.fn.input('Log point message: ')))<CR>",
				desc = "log point",
			},
			{ "<leader>dX", "<Cmd>lua require'dap'.clear_breakpoints()<CR>", desc = "Clear all Breakpoints" },
			{ "<leader>db", "<Cmd>lua require'dap'.toggle_breakpoint()<CR>", desc = "toggle breakpoint" },
			{ "<leader>dc", "<Cmd>lua require'dap'.continue()<CR>", desc = "continue/launch" },
			{ "<leader>dh", "<Cmd>lua require'dap'.step_into()<CR>", desc = "step_into" },
			{ "<leader>dj", "<Cmd>lua require'dap'.step_over()<CR>", desc = "step over" },
			{ "<leader>dk", "<Cmd>lua require'dap'.step_out()<CR>", desc = "step out" },
			{ "<leader>dl", "<Cmd>lua require'dap'.run_last()<CR>", desc = "run last" },
			{ "<leader>do", "<Cmd>lua require'dapui'.open()<CR>", desc = "open debugger" },
			{ "<leader>dq", "<Cmd>lua require'dapui'.close()<CR>", desc = "close debugger" },
			{ "<leader>dr", "<Cmd>lua require'dap'.repl.open()<CR>", desc = "open REPL" },
		},
		visual = {},
	}
end

return M
