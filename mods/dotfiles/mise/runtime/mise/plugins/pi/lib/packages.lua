local common = require("lib.common")
local file = require("file")
local M = {}
local home = assert(os.getenv("HOME"), "HOME is required")

local function command(args, options)
	options = options or {}
	options.cwd = home
	return common.run("pi", args, options)
end

local function parts(source)
	local name, pin = source:match("^(.*)@([^@]+)$")
	if name and #name > (source:find(":") or #source) then
		return name, pin
	end
	return source, "unknown"
end

function M.inventory()
	local text = command({ "list", "--no-approve" }, { timeout = 120 })
	assert(
		text == "" or text:find("User packages:", 1, true) or text:lower():find("no packages installed", 1, true),
		"invalid Pi inventory"
	)
	local rows, user, source = {}, false, nil
	for line in (text .. "\n"):gmatch("(.-)\r?\n") do
		if line:match("^%S") then
			user, source = line == "User packages:", nil
		elseif user then
			local candidate = line:match("^  (%S+)%s*$")
			if candidate then
				source = candidate
			elseif source and line:match("^    %S") then
				if source:match("^npm:") or source:match("^git:") then
					local name, pin = parts(source)
					local path = file.join_path(line:match("^%s*(.-)%s*$"), "package.json")
					if source:match("^npm:") and file.exists(path) then
						pin = common.read_json(path).version
					end
					assert(type(pin) == "string", "invalid Pi installed version")
					rows[name] = { source = source, version = pin }
				end
				source = nil
			end
		end
	end
	return rows
end

function M.finalize()
	local dir = file.join_path(home, ".pi/agent/npm")
	if file.exists(file.join_path(dir, "package.json")) then
		common.run("npm", { "install", "--no-audit", "--no-fund" }, { cwd = dir })
	end
end

function M.install(packages)
	local sources = {}
	for _, pkg in ipairs(packages) do
		local name, pin = common.name(pkg), common.version(pkg)
		local npm = name:match("^npm:")
		assert(
			(npm or name:match("^git:")) and pin ~= "" and pin ~= "latest" and not pin:find("[%s%z]"),
			"Pi packages require an exact version or git ref"
		)
		if npm then
			assert(
				pin:match("^%d+%.%d+%.%d+$") or pin:match("^%d+%.%d+%.%d+[%+%-][%w%.%-]+$"),
				"Pi packages require an exact version or git ref"
			)
		end
		table.insert(sources, { name = name, source = name .. "@" .. pin })
	end
	local rows = M.inventory()
	for _, pkg in ipairs(sources) do
		command({ rows[pkg.name] and rows[pkg.name].source == pkg.source and "update" or "install", pkg.source })
	end
	M.finalize()
end

function M.uninstall(packages)
	local rows = M.inventory()
	for _, pkg in ipairs(packages) do
		local row = rows[common.name(pkg)]
		if row then
			command({ "remove", row.source })
		end
	end
	M.finalize()
end

return M
