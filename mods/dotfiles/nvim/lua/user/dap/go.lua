local dap = require("dap")
local utils = require("user.utils")
-- DAP python
-- you must first: `go install github.com/go-delve/delve/cmd/dlv@latest` into you current project

dap.adapters.go = {
	type = "executable",
	command = "dlv",
	args = { "dap" },
}

dap.configurations.go = {
	{
		type = "go", -- Adapter name
		name = "Debug", -- Configuration name
		request = "launch",
		program = "${file}", -- Start the program from the current file
	},
	{
		type = "go",
		name = "Debug Test", -- Configuration for testing
		request = "launch",
		mode = "test",
		program = "${file}", -- Start with the current test file
	},
	{
		type = "go",
		name = "Debug Package", -- Configuration to test the package
		request = "launch",
		mode = "test",
		program = "./${relativeFileDirname}", -- Start from the package's directory
	},
}
