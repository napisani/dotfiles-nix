local native = require("lib.packages")

function PLUGIN:PackageUpgrade(ctx)
	if ctx.dry_run then
		return {}
	end
	native.install(ctx.packages)
	return {}
end
