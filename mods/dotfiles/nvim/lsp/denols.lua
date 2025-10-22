return {
	-- root_dir = function()
	-- 	local is_deno = vim.fs.root(0, { "deno.json", "deno.jsonc" })
	-- 	return is_deno
	-- end,

	-- stop conflicts with denols
	root_markers = { "deno.json", "deno.jsonc" },
	workspace_required = true,

	on_attach = function(client, bufnr)
		-- use denols to fix impots
		vim.keymap.set("n", "<leader>li", function()
			-- TODO
		end, { buffer = bufnr, desc = "Add missing imports" })
	end,
}
