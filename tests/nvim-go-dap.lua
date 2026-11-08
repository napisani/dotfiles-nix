vim.opt.runtimepath:prepend(assert(arg[1]))
local dap = { adapters = {}, configurations = {} }
package.preload["dap"] = function()
	return dap
end
package.preload["user.utils"] = function()
	return { get_dap_root = function() end }
end
require("user.dap.go")
local adapter = dap.adapters.go
assert(adapter.type == "server", "Delve DAP listens on TCP, not stdio")
assert(adapter.host == "127.0.0.1" and adapter.port == "${port}")
assert(adapter.executable.command == "dlv")
assert(adapter.executable.args[1] == "dap")
assert(adapter.executable.args[2] == "--listen=127.0.0.1:${port}")
if arg[2] then
	vim.fn.writefile({ vim.json.encode(adapter) }, arg[2])
end
print("Go DAP uses the native loopback TCP adapter")
