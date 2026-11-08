local native = require("lib.packages")
local common = require("lib.common")

function PLUGIN:PackageInstalled(ctx)
	local rows, result = native.inventory(), {}
	for _, pkg in ipairs(ctx.packages) do
		local name = common.name(pkg)
		table.insert(
			result,
			rows[name] and { name = name, state = "installed", version = rows[name].version }
				or { name = name, state = "missing" }
		)
	end
	return { packages = result }
end
