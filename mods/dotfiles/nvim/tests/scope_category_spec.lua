local category = require("user.scope.category")
local path = require("user.scope.path")

path.clear_scopes()

assert(category.classify("foo/bar_test.lua") == "tests", "expected _test.* to classify as tests")
assert(category.classify("README.md") == "documentation", "expected README.md to classify as documentation")
assert(category.classify("lua/user/init.lua") == "implementation", "expected plain .lua to fall back to catchall")

for _, name in ipairs(category.list_names()) do
	local patterns = category.patterns_for(name)
	if name ~= "implementation" then
		assert(#patterns > 0, "expected built-in scope patterns: " .. name)
	end
end

local applied, err = category.select_scope("tests")
assert(applied and not err, "expected tests scope selection: " .. tostring(err))
assert(category.active_scope_name() == "tests", "expected tests scope to be active")
assert(category.is_visible("foo/bar_test.lua"), "expected tests visible in tests scope")
assert(not category.is_visible("lua/user/init.lua"), "expected implementation hidden in tests scope")
assert(category.is_tree_visible("foo"), "expected test ancestor directory visible")
-- Some built-in patterns begin with **/, so any directory may contain a test.
assert(category.is_tree_visible("lua"), "expected broad test pattern ancestor directory visible")

local args = category.diffview_pathspec_args()
assert(#args == #category.categories.tests.patterns, "expected one Diffview arg per tests pattern")
for i, pattern in ipairs(category.categories.tests.patterns) do
	assert(args[i] == category.PATHSPEC_INCLUDE .. pattern, "expected tests include pathspec")
end

local docs_applied, docs_err = category.select_scope("documentation")
assert(docs_applied and not docs_err, "expected documentation scope selection")
assert(category.active_scope_name() == "documentation", "expected category selection to replace tests")
assert(category.is_visible("README.md"), "expected documentation visible in documentation scope")
assert(not category.is_visible("foo/bar_test.lua"), "expected tests hidden in documentation scope")

local implementation_applied, implementation_err = category.select_scope("implementation")
assert(implementation_applied and not implementation_err, "expected implementation scope selection")
assert(category.is_visible("lua/user/init.lua"), "expected implementation visible in implementation scope")
assert(not category.is_visible("README.md"), "expected documentation hidden in implementation scope")
local implementation_args = category.diffview_pathspec_args()
assert(implementation_args[1] == category.PATHSPEC_INCLUDE .. "**", "expected implementation catch-all include")
assert(#implementation_args > 1, "expected implementation pathspec exclusions")

local invalid, invalid_error = category.select_scope("missing")
assert(not invalid and invalid_error, "expected unknown built-in scope rejection")

path.clear_scopes()
print("scope_category_spec: ok")
