local common = require("lib.common")
local marketplaces = require("lib.marketplaces")

function PLUGIN:PackageUpgrade(ctx)
	if ctx.dry_run then
		return {}
	end
	for _, marketplace in ipairs(marketplaces.ensure(ctx.packages)) do
		common.run("claude", { "plugin", "marketplace", "update", marketplace })
	end
	for _, pkg in ipairs(ctx.packages) do
		common.run("claude", { "plugin", "update", pkg.name, "--scope", "user", "--yes" })
	end
	return {}
end
