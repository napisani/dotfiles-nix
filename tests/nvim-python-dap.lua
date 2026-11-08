vim.opt.runtimepath:prepend(assert(arg[1]))
local dap = { adapters = {}, configurations = {} }
local python = "/fixture/first/bin/python"
package.preload["dap"] = function()
	return dap
end
package.preload["user.utils"] = function()
	return {
		get_dap_root = function()
			return "/fixture"
		end,
		python_path = function()
			return python
		end,
	}
end
require("user.dap.python")
assert(dap.adapters.python.command == "debugpy-adapter", "adapter depends on project Python")
assert(dap.adapters.python.args == nil, "adapter must use its native entry point")
for _, config in ipairs(dap.configurations.python) do
	if config.type == "python" then
		assert(type(config.pythonPath) == "function", "debuggee Python was captured at startup")
		assert(config.pythonPath() == python)
		python = "/fixture/second/bin/python"
		assert(config.pythonPath() == python)
	end
end
print("Python adapter and dynamic project interpreter contracts passed")
