local overseer = require("overseer")
overseer.setup({})

local tasks = {}

for _, task in ipairs(tasks) do
	overseer.register_template(task)
end
