local keymaps = require("user.lsp.keymaps")

local function convert_to_whichkey_format(keymap_list)
	local result = {}
	for _, km in ipairs(keymap_list) do
		table.insert(result, {
			km.key,
			km.action,
			desc = km.desc,
		})
	end
	return result
end

local normal_mappings = vim.list_extend(
	vim.deepcopy(keymaps.whichkey_groups.normal),
	convert_to_whichkey_format(keymaps.base)
)

table.insert(normal_mappings, { "<leader>lc", "<Plug>ContextCommentaryLine", desc = "(c)omment" })
table.insert(normal_mappings, { "<leader>lR", "<cmd>:LspRestart<cr>", desc = "(R)estart LSPs" })
table.insert(normal_mappings, { "<leader>lm", "<cmd>RenderMarkdown toggle<cr>", desc = "(m)arkdown render toggle" })
table.insert(normal_mappings, {
	"<leader>lw",
	function()
		vim.wo.wrap = not vim.wo.wrap
		vim.notify("wrap: " .. (vim.wo.wrap and "on" or "off"))
	end,
	desc = "(w)rap toggle",
})

local visual_mappings = vim.list_extend(
	vim.deepcopy(keymaps.whichkey_groups.visual),
	convert_to_whichkey_format(keymaps.base_visual)
)

table.insert(visual_mappings, { "<leader>lc", "<Plug>ContextCommentary", desc = "(c)omment" })

return {
	mapping_v = visual_mappings,
	mapping_n = normal_mappings,
	mapping_shared = {},
}

