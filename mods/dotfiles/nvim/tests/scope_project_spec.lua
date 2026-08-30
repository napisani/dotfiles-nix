local category = require("user.scope.category")
local path = require("user.scope.path")
local project = require("user.scope.project")

path.clear_scopes()

_G.EXRC_M = {
	project_config = {
		scopes = {
			frontend = { "src/**/*.ts", "src/**/*.tsx" },
			integration = { "**/integration/**" },
			tests = { "should-not-be-accepted" },
			broken = { "../outside" },
		},
	},
}

local scopes = project.list_scopes()
assert(#scopes == 2, "expected invalid and reserved project scopes to be ignored")

local picker = require("user.whichkey.categories")
local items = picker.scope_items()
assert(#items == 5, "expected three built-ins plus two project scopes")
for index, name in ipairs({ "tests", "documentation", "implementation", "frontend", "integration" }) do
	assert(items[index].scope_name == name, "expected deterministic picker order")
end
assert(scopes[1].name == "frontend" and scopes[2].name == "integration", "expected project scopes sorted by name")
assert(#scopes[1].patterns == 2, "expected project glob arrays to be preserved")

local applied, err = project.select_scope("frontend")
assert(applied and not err, "expected project scope selection: " .. tostring(err))
assert(path.active_scope_kind() == "glob", "expected project scope to use glob runtime")
assert(path.is_visible("src/components/App.tsx"), "expected selected project glob to filter files")
assert(not path.is_visible("README.md"), "expected selected project glob to hide unrelated files")

local builtin_applied, builtin_err = category.select_scope("tests")
assert(builtin_applied and not builtin_err, "expected built-in scope selection: " .. tostring(builtin_err))
assert(category.active_scope_name() == "tests", "expected built-in scope to replace project scope")
assert(path.active_scope_kind() == "category", "expected built-in scope to be active")
assert(category.is_visible("foo_test.lua"), "expected selected tests scope to show test files")
assert(not category.is_visible("src/main.lua"), "expected selected tests scope to hide implementation files")

local directory_applied, directory_err = path.add_scope("src")
assert(directory_applied and not directory_err, "expected directory scope selection")
assert(path.active_scope_kind() == "directory", "expected directory scope to replace built-in scope")
assert(category.active_scope_name() == nil, "expected directory scope to clear built-in selection")

path.clear_scopes()
_G.EXRC_M = nil
print("scope_project_spec: ok")
