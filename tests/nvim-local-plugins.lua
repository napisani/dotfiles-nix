vim.opt.runtimepath:prepend(assert(arg[1]))
vim.env.XDG_DATA_HOME = vim.fn.tempname()
vim.fn.mkdir(vim.fn.stdpath("data") .. "/lazy/lazy.nvim", "p")
local specs
package.preload["lazy"] = function()
	return {
		setup = function(config)
			specs = config.spec
		end,
	}
end
for _, module in ipairs({ "user.trouble", "user.blink", "user.snacks", "user.plugins.ai.vantage" }) do
	package.preload[module] = function()
		return { opts = {}, opts_extend = {}, cmd = {}, keys = {} }
	end
end
require("user.lazy")
local found = {}
for _, spec in ipairs(specs) do
	if spec.name == "vantage.nvim" or spec.name == "scrollbacktamer.nvim" then
		local project = spec.name == "vantage.nvim" and "vantage-nvim" or spec.name
		assert(spec.dir == arg[2] .. "/" .. project, "local plugin ignores the canonical source: " .. spec.dir)
		found[project] = true
	end
end
assert(found["vantage-nvim"] and found["scrollbacktamer.nvim"])
print("Local plugins follow the canonical source checkout")
