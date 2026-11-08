local native = require("lib.packages")

function PLUGIN:PackageUninstall(ctx)
	if ctx.dry_run then
		return {}
	end
	native.uninstall(ctx.packages)
	return {}
end
