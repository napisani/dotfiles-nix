return {
	-- root_dir = function()
	-- 	local is_deno = vim.fs.root(0, { "deno.json", "deno.jsonc" })
	-- 	return is_deno
	-- end,

	-- stop conflicts with denols
	root_markers = { "deno.json", "deno.jsonc" },
	workspace_required = true,
}
