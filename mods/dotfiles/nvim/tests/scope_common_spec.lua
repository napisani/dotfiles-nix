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

-- Glob scopes replace directory scopes and filter every path-list/picker seam.
do
	path.add_scope("src/app")
	local applied, err = path.set_glob_scope({ "lua/**/init?.lua", "lua/user/other.lua" })
	assert(applied and not err, "expected valid glob scope: " .. tostring(err))
	local active = path.active_scope()
	assert(#active == 2 and active[1] == "lua/**/init?.lua", "expected glob array to be active")
	assert(path.active_scope_kind() == "glob", "expected active scope kind to be glob")
	assert(path.is_visible("lua/init1.lua"), "expected ** to match zero directories")
	assert(path.is_visible("lua/user/init2.lua"), "expected ** to match nested directories")
	assert(path.is_visible("lua/user/other.lua"), "expected the second glob to match")
	assert(not path.is_visible("lua/user/unrelated.lua"), "expected glob scope to exclude non-matches")
	assert(path.is_tree_visible("lua"), "expected a glob ancestor directory to remain visible")
	assert(path.is_tree_visible("lua/user"), "expected a nested glob ancestor directory to remain visible")
	assert(not path.is_tree_visible("pub"), "expected an unrelated tree directory to be hidden")

	local picker = common.apply_to_picker({})
	assert(picker.cwd == nil, "expected glob scope not to change picker cwd")
	assert(picker.transform({ file = "lua/user/init2.lua" }, {}) ~= false, "expected in-scope picker item")
	assert(picker.transform({ file = "lua/user/other.lua" }, {}) ~= false, "expected second glob item kept")
	assert(
		picker.transform({ file = "lua/user/unrelated.lua" }, {}) == false,
		"expected out-of-scope picker item dropped"
	)

	local filtered = common.filter_paths({ "lua/init1.lua", "lua/user/other.lua", "README.md" })
	assert(#filtered == 2, "expected path-list filtering to use all glob entries")
	assert(filtered[1] == "lua/init1.lua" and filtered[2] == "lua/user/other.lua", "expected path-list order")

	local args = common.diffview_pathspec_args()
	assert(
		#args == 2
			and args[1] == category.PATHSPEC_INCLUDE .. "lua/**/init?.lua"
			and args[2] == category.PATHSPEC_INCLUDE .. "lua/user/other.lua",
		"expected one Diffview pathspec per glob"
	)
	assert(
		common.diffview_pathspec_args("lua/user/unrelated.lua") == nil,
		"expected target outside glob scope to be hidden"
	)

	-- Positive category pathspecs cannot be ORed with positive glob scopes:
	-- Diffview needs the materialized intersection as exact file paths.
	path.set_glob_scope("lua/**/*.lua")
	category.set_enabled("implementation", false)
	local exact = common.diffview_pathspec_args(nil, {
		"lua/feature_test.lua",
		"lua/implementation.lua",
		"docs/guide.md",
	})
	assert(#exact == 1 and exact[1] == "lua/feature_test.lua", "expected exact glob/category intersection")
	category.reset_all()

	local unchanged = path.active_scope()
	local invalid = path.set_glob_scope({ "../outside" })
	local still_active = path.active_scope()
	assert(
		not invalid and #still_active == #unchanged and still_active[1] == unchanged[1],
		"expected invalid glob not to replace active scope"
	)
	path.clear_scopes()
end

print("scope_common_spec: ok")
