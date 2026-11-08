local common = require("lib.common")

function PLUGIN:PackageInstalled(ctx)
	local text = common.run("claude", { "plugin", "list", "--json" }, { timeout = 120 })
	assert(text:match("^%s*%["), "invalid Claude inventory")
	local rows = common.decode(text)
	local installed = {}
	for _, row in ipairs(rows) do
		assert(type(row.id) == "string" and type(row.scope) == "string", "invalid Claude inventory")
		if row.scope == "user" then
			installed[row.id] = row.version or "unknown"
		end
	end
	local result = {}
	for _, pkg in ipairs(ctx.packages) do
		local name = common.name(pkg)
		table.insert(
			result,
			installed[name] and { name = name, state = "installed", version = installed[name] }
				or { name = name, state = "missing" }
		)
	end
	return { packages = result }
end
