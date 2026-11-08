local common = require("lib.common")
local marketplaces = require("lib.marketplaces")

function PLUGIN:PackageInstall(ctx)
	if ctx.dry_run then
		return {}
	end
	marketplaces.ensure(ctx.packages)
	for _, pkg in ipairs(ctx.packages) do
		common.run("claude", { "plugin", "install", common.name(pkg), "--scope", "user" })
	end
	return {}
end
