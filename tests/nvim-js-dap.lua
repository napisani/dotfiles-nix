vim.opt.runtimepath:prepend(assert(arg[1]))
local dap = { adapters = {}, configurations = {} }
package.preload["dap"] = function()
	return dap
end
package.preload["dap.utils"] = function()
	return { pick_process = function() end }
end
package.preload["user.utils"] = function()
	return { get_dap_root = function() end }
end
require("user.dap.typescript")
for _, name in ipairs({ "pwa-node", "pwa-chrome", "node-terminal" }) do
	local adapter
	dap.adapters[name](function(value)
		adapter = value
	end)
	assert(adapter.type == "server" and adapter.host == "127.0.0.1")
	assert(adapter.executable.command == "node")
	assert(vim.fn.filereadable(adapter.executable.args[1]) == 1)
	assert(adapter.executable.args[2] == "${port}" and adapter.executable.args[3] == "127.0.0.1")
	if arg[2] then
		vim.fn.writefile({ vim.json.encode(adapter) }, arg[2])
	end
end
print("JS adapter configurations resolve the installed native module")
