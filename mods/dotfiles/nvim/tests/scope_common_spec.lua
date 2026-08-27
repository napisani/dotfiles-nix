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

local function has(list, want)
	for _, v in ipairs(list) do
		if v == want then
			return true
		end
	end
	return false
end

-- diffview pathspec composition: no scope, directory only, and the two
-- category modes crossed with a directory scope.
do
	assert(#common.diffview_pathspec_args() == 0, "expected no pathspec args with nothing scoped")

	path.add_scope("src/app")
	local dir_only = common.diffview_pathspec_args()
	assert(
		#dir_only == 1 and dir_only[1] == category.PATHSPEC_INCLUDE .. "src/app/**",
		"expected the scope dir as the only pathspec: " .. vim.inspect(dir_only)
	)

	-- exclude mode: category negatives plus the scope dir as the positive
	category.set_enabled("tests", false)
	local exclude_mode = common.diffview_pathspec_args()
	assert(has(exclude_mode, category.PATHSPEC_EXCLUDE .. "**/*_test.*"), "expected category negative to survive")
	assert(
		has(exclude_mode, category.PATHSPEC_INCLUDE .. "src/app/**"),
		"expected the scope dir alongside category negatives"
	)
	category.reset_all()

	-- include mode: positives must be confined to the dir, not ORed beside it
	category.set_enabled("implementation", false)
	local include_mode = common.diffview_pathspec_args()
	local prefix = category.PATHSPEC_INCLUDE .. "src/app/"
	for _, arg in ipairs(include_mode) do
		assert(arg:sub(1, #prefix) == prefix, "expected every positive pathspec under the scope dir: " .. arg)
	end
	assert(has(include_mode, prefix .. "**/*_test.*"), "expected the dir-prefixed pattern")
	category.reset_all()
	path.clear_scopes()
end

-- a single-file target is narrower than any scope: kept whole, or nothing
do
	path.add_scope("src/app")
	local kept = common.diffview_pathspec_args("src/app/impl.lua")
	assert(#kept == 1 and kept[1] == "src/app/impl.lua", "expected an in-scope file to pass through")
	assert(
		common.diffview_pathspec_args("src/other/impl.lua") == nil,
		"expected a file outside the dir scope to be nil"
	)

	category.set_enabled("tests", false)
	assert(common.diffview_pathspec_args("src/app/impl_test.lua") == nil, "expected a hidden-category file to be nil")
	category.reset_all()
	path.clear_scopes()
end

print("scope_common_spec: ok")
