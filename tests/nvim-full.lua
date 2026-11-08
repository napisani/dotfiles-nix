local function check()
	for _, name in ipairs(require("user.plugin_registry").get_all_modules()) do
		assert(require("user.plugins." .. name))
	end
	local dap = require("dap")
	assert(dap.adapters.go.type == "server")
	assert(dap.adapters.python.command == "debugpy-adapter")
	assert(type(dap.adapters["pwa-node"]) == "function")
	assert(vim.fn.py3eval("__import__('sys').version_info.major") == 3)
	local plugins = require("lazy.core.config").plugins
	assert(not plugins["mason.nvim"] and not plugins["mason-lspconfig.nvim"] and not plugins["mason-nvim-dap.nvim"])
	local languages = { "lua", "python", "go", "bash" }
	assert(
		vim.wait(180000, function()
			for _, language in ipairs(languages) do
				local parser = vim.fn.stdpath("data") .. "/site/parser/" .. language .. ".so"
				if not vim.uv.fs_stat(parser) or not pcall(vim.treesitter.language.add, language) then
					return false
				end
			end
			return true
		end, 100),
		"native parser installation timed out"
	)
	for _, language in ipairs(languages) do
		assert(#vim.treesitter.get_string_parser("", language):parse() == 1)
	end
	local messages = vim.fn.execute("messages")
	assert(not messages:find("Error in", 1, true), messages)
	assert(not messages:find("Error detected", 1, true), messages)
	assert(not messages:find("] error:", 1, true), messages)
end

-- Headless Neovim can exit zero after a startup or :luafile error.
local ok, error_message = xpcall(check, debug.traceback)
if not ok then
	vim.api.nvim_err_writeln(error_message)
	vim.cmd("cquit 1")
else
	print("FULL_CONFIG_MODULES_AND_PROVIDERS_PASS")
	vim.cmd("qa!")
end
