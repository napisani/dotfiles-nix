local cmd = require("cmd")
local json = require("json")

function PLUGIN:PackageInstalled(ctx)
	return json.decode(cmd.exec('"$FIXTURE_NODE" "$FIXTURE_CLI" status', {
		env = { FIXTURE_REQUEST = json.encode(ctx.packages) },
	}))
end
