local scopes = require("user.scope.path")
local find_files = require("user.snacks.find_files")
local refresh = require("user.refresh")
local categories = require("user.whichkey.categories")

local function trim(text)
	return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function response_globs(markdown)
	local text = trim(markdown)
	text = text:gsub("^```[%w_-]*%s*", ""):gsub("%s*```$", "")
	text = trim(text)
	local ok, globs = pcall(vim.json.decode, text)
	if not ok or type(globs) ~= "table" or #globs == 0 then
		return nil, "Vantage did not return a non-empty JSON glob array"
	end
	for key, glob in pairs(globs) do
		if type(key) ~= "number" or type(glob) ~= "string" then
			return nil, "Vantage returned an invalid JSON glob array"
		end
	end
	return globs
end

local function request_adhoc_scope()
	local ok, vantage = pcall(require, "vantage")
	if not ok then
		vim.notify("vantage.nvim not found", vim.log.levels.WARN)
		return
	end

	vantage.prompt({
		kind = "scope-description",
		title = "Describe file scope",
		on_submit = function(description)
			vantage.question({
				runtime = "agent",
				args = table.concat({
					"Inspect the workspace with read-only tools as needed before choosing the files and paths.",
					"Translate the user's description into a non-empty JSON array of workspace-relative include globs.",
					"Return only the JSON array: no Markdown, explanation, code fence, or quotes outside JSON strings.",
					"Include specific file paths when you can identify them, and add directory globs only when they cover related files involved in the request.",
					"Each entry may use literals, /, *, **, and ?. Do not use absolute paths, .., braces, or whitespace inside entries.",
					"The globs must be suitable for ripgrep and Git pathspec glob matching.",
					"User's scope description:",
					description,
				}, "\n\n"),
				callback = function(err, result)
					if err then
						vim.notify("Vantage scope generation failed: " .. tostring(err), vim.log.levels.ERROR)
						return
					end
					local globs, parse_error = response_globs(result and result.markdown)
					if not globs then
						vim.notify("Vantage scope generation failed: " .. parse_error, vim.log.levels.ERROR)
						return
					end
					local applied, scope_error = scopes.set_glob_scope(globs)
					if not applied then
						vim.notify("Invalid Vantage scope: " .. tostring(scope_error), vim.log.levels.ERROR)
						return
					end
					vim.notify("Vantage scope set: " .. table.concat(globs, ", "), vim.log.levels.INFO)
					refresh.refresh_open_nvim_trees()
				end,
			})
		end,
	})
end

local normal_mappings = {
	{
		"<leader><leader>sp",
		function()
			find_files.pick_scopes(nil, refresh.refresh_open_nvim_trees)
		end,
		desc = "(p)ath scope",
	},
	{
		"<leader><leader>st",
		function()
			categories.pick_categories(refresh.refresh_open_nvim_trees)
		end,
		desc = "(t)oggle scopes",
	},
	{
		"<leader><leader>sv",
		request_adhoc_scope,
		desc = "(v)antage scope",
	},
	{
		"<leader><leader>sx",
		function()
			scopes.clear_scopes()
			categories.reset_all()
			refresh.refresh_open_nvim_trees()
		end,
		desc = "(x) clear all scopes",
	},
}

return {
	mapping_v = {},
	mapping_n = normal_mappings,
	mapping_shared = {},
}
