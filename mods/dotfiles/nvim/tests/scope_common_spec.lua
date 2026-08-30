local path = require("user.scope.path")
local category = require("user.scope.category")
local common = require("user.scope.common")

path.clear_scopes()

local function has(list, want)
	for _, value in ipairs(list) do
		if value == want then
			return true
		end
	end
	return false
end

-- A pre-existing picker transform still runs after scope filtering.
do
	local pre_existing_calls = {}
	local opts = {
		transform = function(item)
			table.insert(pre_existing_calls, item)
			if item.text == "drop-me-existing" then
				return false
			end
		end,
	}
	local applied = common.apply_to_picker(opts)
	assert(applied.transform({ file = "impl.lua", text = "keep-me" }, {}) ~= false, "expected item kept")
	assert(applied.transform({ file = "impl.lua", text = "drop-me-existing" }, {}) == false, "expected existing drop")
	assert(#pre_existing_calls == 2, "expected existing transform to run")
end

-- Directory scope narrows the picker cwd and Diffview pathspec.
do
	path.add_scope("src/app")
	local picker = common.apply_to_picker({})
	assert(picker.cwd == "src/app", "expected directory scope cwd")
	local args = common.diffview_pathspec_args()
	assert(#args == 1 and args[1] == category.PATHSPEC_INCLUDE .. "src/app/**", "expected directory pathspec")
	assert(common.is_visible("src/app/main.lua"), "expected in-directory path visible")
	assert(not common.is_visible("src/other/main.lua"), "expected out-of-directory path hidden")
	path.clear_scopes()
end

-- Glob arrays filter every path-list/picker seam and preserve all entries.
do
	local applied, err = path.set_glob_scope({ "lua/**/init?.lua", "lua/user/other.lua" }, "initializers")
	assert(applied and not err, "expected valid glob scope: " .. tostring(err))
	assert(path.active_scope_name() == "initializers", "expected named glob scope")
	assert(path.active_scope_kind() == "glob", "expected glob kind")
	assert(path.is_visible("lua/init1.lua"), "expected ** to match zero directories")
	assert(path.is_visible("lua/user/init2.lua"), "expected ** to match nested directories")
	assert(path.is_visible("lua/user/other.lua"), "expected second glob match")
	assert(not path.is_visible("lua/user/unrelated.lua"), "expected unrelated path hidden")
	assert(path.is_tree_visible("lua/user"), "expected glob ancestor visible")
	assert(not path.is_tree_visible("pub"), "expected unrelated tree hidden")

	local picker = common.apply_to_picker({})
	assert(picker.cwd == nil, "expected glob not to change picker cwd")
	assert(picker.transform({ file = "lua/user/init2.lua" }, {}) ~= false, "expected picker match")
	assert(picker.transform({ file = "lua/user/unrelated.lua" }, {}) == false, "expected picker non-match dropped")

	local filtered = common.filter_paths({ "lua/init1.lua", "lua/user/other.lua", "README.md" })
	assert(
		#filtered == 2 and filtered[1] == "lua/init1.lua" and filtered[2] == "lua/user/other.lua",
		"expected path filtering"
	)

	local args = common.diffview_pathspec_args()
	assert(#args == 2, "expected one Diffview pathspec per glob")
	assert(has(args, category.PATHSPEC_INCLUDE .. "lua/**/init?.lua"), "expected first glob pathspec")
	assert(has(args, category.PATHSPEC_INCLUDE .. "lua/user/other.lua"), "expected second glob pathspec")
	path.clear_scopes()
end

-- Built-in categories use the same shared active scope and replace globs.
do
	path.set_glob_scope("src/**/*.lua", "lua")
	local selected, err = category.select_scope("tests")
	assert(selected and not err, "expected category selection")
	assert(path.active_scope_kind() == "category", "expected category to replace glob")
	assert(path.active_scope_name() == "tests", "expected selected category name")
	assert(common.is_visible("foo_test.lua"), "expected test visible")
	assert(not common.is_visible("src/main.lua"), "expected implementation hidden")
	assert(
		common.diffview_pathspec_args()[1] == category.PATHSPEC_INCLUDE .. "**/*_test.*",
		"expected category pathspec"
	)
	assert(common.is_tree_visible("foo"), "expected category ancestor tree visible")
	path.clear_scopes()
end

-- A single-file target is narrower than any active scope.
do
	path.set_glob_scope("src/**/*.lua")
	assert(#common.diffview_pathspec_args("src/main.lua") == 1, "expected in-scope target")
	assert(common.diffview_pathspec_args("README.md") == nil, "expected out-of-scope target hidden")
	path.clear_scopes()
end

print("scope_common_spec: ok")
