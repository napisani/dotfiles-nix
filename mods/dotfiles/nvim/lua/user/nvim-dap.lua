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

local dap_vscode_status_ok, dap_vscode = pcall(require, "dap.ext.vscode")
if not dap_vscode_status_ok then
	vim.notify("nvim-dap-vscode not found")
	return
end

local dap_virtual_text_status_ok, dap_virtual_text = pcall(require, "nvim-dap-virtual-text")
local utils = require("user.utils")

-- # Sign
-- vim.fn.sign_define("DapBreakpoint", { text = "🟥", texthl = "", linehl = "", numhl = "" })
-- vim.fn.sign_define("DapBreakpointCondition", { text = "🟧", texthl = "", linehl = "", numhl = "" })
-- vim.fn.sign_define("DapLogPoint", { text = "🟩", texthl = "", linehl = "", numhl = "" })
-- vim.fn.sign_define("DapStopped", { text = "👉", texthl = "", linehl = "", numhl = "" })
-- vim.fn.sign_define("DapBreakpointRejected", { text = "⬜", texthl = "", linehl = "", numhl = "" })

-- # DAP Virtual Text
dap_virtual_text.setup({})

dapui.setup({})

dap.listeners.after.event_initialized["dapui_config"] = function()
	dapui.open({})
end
dap.listeners.before.event_terminated["dapui_config"] = function()
	dapui.close({})
end
dap.listeners.before.event_exited["dapui_config"] = function()
	dapui.close({})
end

require("user.dap.typescript")
require("user.dap.rust")
require("user.dap.python")
require("user.dap.go")

dap_vscode.load_launchjs(utils.get_debugger_launch_file(), {
	["pwa-node"] = { "javascript", "typescript" },
	delve = { "go" },
	python = { "python" },
	codelldb = { "c", "cpp", "rust" },
})
