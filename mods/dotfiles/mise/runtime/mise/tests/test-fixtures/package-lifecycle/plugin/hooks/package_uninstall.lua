local cmd = require("cmd")
local json = require("json")

function PLUGIN:PackageUninstall(ctx)
	cmd.exec('"$FIXTURE_NODE" "$FIXTURE_CLI" uninstall', {
		env = { FIXTURE_REQUEST = json.encode(ctx.packages) },
	})
	return {}
end
