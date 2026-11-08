local common = require("lib.common")

function PLUGIN:PackageUninstall(ctx)
	if ctx.dry_run then
		return {}
	end
	for _, pkg in ipairs(ctx.packages) do
		common.run("claude", { "plugin", "uninstall", common.name(pkg), "--scope", "user", "--keep-data" })
	end
	return {}
end
