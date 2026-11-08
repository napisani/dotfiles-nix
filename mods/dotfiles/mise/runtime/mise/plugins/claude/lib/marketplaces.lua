local common = require("lib.common")
local file = require("file")
local M = {}

function M.ensure(packages)
	local requested, seen = {}, {}
	for _, pkg in ipairs(packages) do
		local marketplace = common.name(pkg):match("@([^@]+)$")
		assert(marketplace, "Claude plugin requires a marketplace")
		if not seen[marketplace] then
			table.insert(requested, marketplace)
			seen[marketplace] = true
		end
	end
	if #requested == 0 then
		return requested
	end
	local text = common.run("claude", { "plugin", "marketplace", "list", "--json" }, { timeout = 120 })
	assert(text:match("^%s*%["), "invalid Claude marketplace inventory")
	local registered = {}
	for _, row in ipairs(common.decode(text)) do
		assert(type(row.name) == "string" and row.name ~= "", "invalid Claude marketplace inventory")
		registered[row.name] = true
	end
	local settings, missing = nil, {}
	for _, name in ipairs(requested) do
		if not registered[name] then
			if not settings then
				local dir = os.getenv("CLAUDE_CONFIG_DIR") or file.join_path(assert(os.getenv("HOME")), ".claude")
				settings = common.read_json(file.join_path(dir, "settings.json"))
			end
			local declaration = (settings.extraKnownMarketplaces or {})[name]
			local source = declaration and declaration.source
			assert(
				source
					and source.source == "github"
					and source.ref == nil
					and type(source.repo) == "string"
					and source.repo:match("^[%w_][%w_.-]*/[%w_][%w_.-]*$"),
				"missing GitHub marketplace declaration for " .. name
			)
			table.insert(missing, source.repo)
		end
	end
	for _, repo in ipairs(missing) do
		common.run("claude", { "plugin", "marketplace", "add", repo, "--scope", "user" })
	end
	return requested
end

return M
