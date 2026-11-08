local cmd = require("cmd")
local json = require("json")

function PLUGIN:PackageInstall(ctx)
	if not ctx.dry_run then
		cmd.exec('"$FIXTURE_NODE" "$FIXTURE_CLI" install', {
			env = { FIXTURE_REQUEST = json.encode(ctx.packages) },
		})
	end
	return {}
end
