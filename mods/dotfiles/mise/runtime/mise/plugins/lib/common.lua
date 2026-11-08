local cmd = require("cmd")
local file = require("file")
local json = require("json")
local M = {}

function M.run(command, args, options)
	local function quote(value)
		assert(type(value) == "string" and not value:find("%z"), "invalid command argument")
		return "'" .. value:gsub("'", "'\"'\"'") .. "'"
	end
	local words = { quote(command) }
	for _, value in ipairs(args) do
		table.insert(words, quote(value))
	end
	options = options or {}
	return cmd.exec(table.concat(words, " "), options)
end

function M.decode(text)
	local ok, value = pcall(json.decode, text)
	assert(ok, "invalid package data JSON")
	return value
end

function M.read_json(path)
	return M.decode(file.read(path))
end

function M.name(pkg)
	assert(
		type(pkg.name) == "string" and pkg.name ~= "" and not pkg.name:find("^[%s%-]") and not pkg.name:find("%z"),
		"invalid package name"
	)
	return pkg.name
end

function M.version(pkg)
	return pkg.version or "latest"
end

return M
