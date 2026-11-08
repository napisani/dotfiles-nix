local dap = require("dap")
local utils = require("user.utils")

local function dap_root()
	return utils.get_dap_root()
end

local function with_js_debug(config)
	return vim.tbl_extend("force", {
		cwd = dap_root,
		sourceMaps = true,
		outFiles = {
			"${workspaceFolder}/dist/**/*.js",
			"${workspaceFolder}/apps/*/dist/**/*.js",
			"${workspaceFolder}/**/*.(m|c|)js",
			"!**/node_modules/**",
		},
		resolveSourceMapLocations = {
			"${workspaceFolder}/**",
			"!**/node_modules/**",
		},
		skipFiles = {
			"<node_internals>/**",
			"node_modules/**",
		},
	}, config)
end

local function js_adapter(callback)
	local result = vim.system({
		vim.fn.expand("~/.local/bin/mise"),
		"where",
		"github:microsoft/vscode-js-debug",
	}, { text = true }):wait(10000)
	assert(result.code == 0, "Native JS debugger is unavailable; run sys-update apply")
	local server = vim.trim(result.stdout) .. "/src/dapDebugServer.js"
	assert(vim.fn.filereadable(server) == 1, "Native JS debugger module is missing")
	callback({
		type = "server",
		host = "127.0.0.1",
		port = "${port}",
		executable = {
			command = "node",
			args = { server, "${port}", "127.0.0.1" },
		},
	})
end

for _, name in ipairs({ "pwa-node", "pwa-chrome", "node-terminal" }) do
	dap.adapters[name] = js_adapter
end

local js_based_langs = {
  "javascript",
  "typescript",
  "javascriptreact",
  "typescriptreact",
  "vue",
  "svelte",
}

for _idx, language in ipairs(js_based_langs) do
		dap.configurations[language] = {
			with_js_debug({
				type = "pwa-node",
				request = "launch",
				name = "Launch node file",
				program = "${file}",
			}),
			with_js_debug({
				type = "pwa-node",
				request = "attach",
				name = "Attach to node process (pick pid)",
				processId = require("dap.utils").pick_process,
			}),
			with_js_debug({
				type = "pwa-node",
				request = "attach",
				name = "Attach to node process (port 9229)",
				port = 9229,
			}),
    -- {
    --   type = "pwa-node",
    --   request = "launch",
    --   name = "Debug node build script",
    --   -- trace = true, -- include debugger info
    --   runtimeExecutable = "pnpm",
    --   runtimeArgs = { "build" },
    --   env = {
    --     NODE_OPTIONS = "--inspect",
    --   },
    --   rootPath = "${workspaceFolder}",
    --   cwd = "${workspaceFolder}",
    --   console = "integratedTerminal",
    --   internalConsoleOptions = "neverOpen",
    -- },
			with_js_debug({
				type = "pwa-node",
				request = "launch",
				name = "Debug Jest tests",
				-- trace = true, -- include debugger info
				runtimeExecutable = "node",
				runtimeArgs = {
					"./node_modules/jest/bin/jest.js",
					"--runInBand",
				},
				console = "integratedTerminal",
				internalConsoleOptions = "neverOpen",
			}),
			with_js_debug({
				type = "pwa-node",
				request = "launch",
				name = "Debug Jest current file",
				-- trace = true, -- include debugger info
				runtimeExecutable = "node",
				runtimeArgs = {
					"./node_modules/jest/bin/jest.js",
					"--runInBand",
					"--testPathPattern",
					"${file}",
				},
				console = "integratedTerminal",
				internalConsoleOptions = "neverOpen",
			}),
    {
      name = "-- launch.json --",
    }
  }
end
