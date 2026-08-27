local path = require("user.scope.path")
local category = require("user.scope.category")
local common = require("user.scope.common")

path.clear_scopes()
category.reset_all()

do
	local pre_existing_calls = {}
	local opts = {
		transform = function(item, ctx)
			table.insert(pre_existing_calls, item)
			if item.text == "drop-me-existing" then
				return false
			end
		end,
	}

	local applied = common.apply_to_picker(opts)
	assert(type(applied.transform) == "function", "expected apply_to_picker to install a transform")

	category.set_enabled("tests", false)

	-- dropped by category filtering only
	assert(applied.transform({ file = "foo_test.lua", text = "foo_test.lua" }, {}) == false, "expected category drop")
	-- dropped by the pre-existing transform only
	assert(applied.transform({ file = "impl.lua", text = "drop-me-existing" }, {}) == false, "expected existing drop")
	-- kept by both
	assert(applied.transform({ file = "impl.lua", text = "keep-me" }, {}) ~= false, "expected item kept by both")

	assert(#pre_existing_calls >= 1, "expected the pre-existing transform to still be invoked")

	category.reset_all()
end

do
	path.add_scope("/tmp/some-scope-dir")
	local applied = common.apply_to_picker({})
	assert(applied.cwd == "/tmp/some-scope-dir", "expected apply_to_picker to delegate cwd to path scope")
	path.clear_scopes()
end

print("scope_common_spec: ok")
