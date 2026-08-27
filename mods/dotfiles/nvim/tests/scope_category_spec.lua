local category = require("user.scope.category")

category.reset_all()

assert(category.classify("foo/bar_test.lua") == "tests", "expected _test.* to classify as tests")
assert(category.classify("README.md") == "documentation", "expected README.md to classify as documentation")
assert(category.classify("lua/user/init.lua") == "implementation", "expected plain .lua to fall back to catchall")

assert(category.is_visible("foo/bar_test.lua"), "expected tests visible right after reset_all")
assert(category.is_visible("README.md"), "expected documentation visible right after reset_all")
assert(category.is_visible("lua/user/init.lua"), "expected implementation visible right after reset_all")

category.set_enabled("tests", false)
assert(not category.is_visible("foo/bar_test.lua"), "expected tests hidden once disabled")
assert(category.is_visible("lua/user/init.lua"), "expected catchall to stay visible when tests disabled")

category.reset_all()
assert(category.is_visible("foo/bar_test.lua"), "expected reset_all to re-enable tests")

do
	local item = { file = "foo/bar_test.lua" }
	category.set_enabled("tests", false)
	assert(category.transform(item, {}) == false, "expected transform to drop item in disabled category")
	category.reset_all()
	assert(category.transform(item, {}) ~= false, "expected transform to keep item in enabled category")
end

do
	category.set_enabled("tests", false)
	local filtered = category.filter_paths({ "a/foo.lua", "a/foo_test.lua", "b/bar.lua" })
	assert(#filtered == 2, "expected filter_paths to drop only the disabled-category entry")
	assert(filtered[1] == "a/foo.lua" and filtered[2] == "b/bar.lua", "expected filter_paths to preserve order")
	category.reset_all()
end

do
	local args = category.diffview_pathspec_args()
	assert(#args == 0, "expected no pathspec restriction when all categories enabled")
end

do
	category.set_enabled("tests", false)
	local args = category.diffview_pathspec_args()
	local tests_patterns = category.categories.tests.patterns
	assert(#args == #tests_patterns, "expected one exclude arg per tests pattern")
	for i, pattern in ipairs(tests_patterns) do
		assert(args[i] == ":!" .. pattern, "expected exclude-mode arg to be :!-prefixed: " .. tostring(args[i]))
	end
	category.reset_all()
end

do
	category.set_enabled("implementation", false)
	local args = category.diffview_pathspec_args()
	local doc_patterns = category.categories.documentation.patterns
	for _, pattern in ipairs(doc_patterns) do
		local found = false
		for _, arg in ipairs(args) do
			if arg == pattern then
				found = true
			end
			assert(arg:sub(1, 2) ~= ":!", "expected include-mode args to be bare, not :!-prefixed: " .. arg)
		end
		assert(found, "expected documentation pattern present in include-mode args: " .. pattern)
	end
	category.reset_all()
end

do
	for _, name in ipairs(category.list_names()) do
		category.set_enabled(name, false)
	end
	local args = category.diffview_pathspec_args()
	assert(#args == 1 and args[1] == category.NOTHING_MATCHES_SENTINEL, "expected match-nothing sentinel")
	category.reset_all()
end

print("scope_category_spec: ok")
