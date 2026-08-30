local M = {}

local function scope_filter(absolute_path)
	local common_scope = require("user.scope.common")

	if vim.fn.isdirectory(absolute_path) == 1 then
		return not common_scope.is_tree_visible(absolute_path)
	end

	return not common_scope.is_visible(absolute_path)
end

local function on_attach(bufnr)
	local api = require("nvim-tree.api")
	api.map.on_attach.default(bufnr)
	-- The custom filter is the centralized path/category scope filter. Do not
	-- expose NvimTree's toggle for it, or the tree could bypass active scopes.
	pcall(vim.keymap.del, "n", "U", { buffer = bufnr })

	local function opts(desc)
		return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
	end

	vim.keymap.set("n", "l", api.node.open.edit, opts("Open"))
	vim.keymap.set("n", "h", api.node.navigate.parent_close, opts("Close Directory"))
	vim.keymap.set("n", "v", api.node.open.vertical, opts("Open: Vertical Split"))
end

function M.setup()
	local ok, nvim_tree = pcall(require, "nvim-tree")
	if not ok then
		return
	end

	nvim_tree.setup({
		on_attach = on_attach,
		hijack_netrw = true,
		sync_root_with_cwd = false,
		update_focused_file = { enable = true, update_cwd = false },
		filters = { enable = true, custom = scope_filter },
		renderer = {
			root_folder_modifier = ":t",
			icons = {
				glyphs = {
					default = "",
					symlink = "",
					folder = {
						arrow_open = "",
						arrow_closed = "",
						default = "",
						open = "",
						empty = "",
						empty_open = "",
						symlink = "",
						symlink_open = "",
					},
					git = {
						unstaged = "",
						staged = "S",
						unmerged = "",
						renamed = "➜",
						untracked = "U",
						deleted = "",
						ignored = "◌",
					},
				},
			},
		},
		diagnostics = {
			enable = true,
			show_on_dirs = true,
			icons = { hint = "", info = "", warning = "", error = "" },
		},
		view = { width = 50, side = "left" },
	})
end

function M.toggle()
	local ok, api = pcall(require, "nvim-tree.api")
	if ok then
		api.tree.toggle({ find_file = true })
	end
end

function M.reload()
	local ok, api = pcall(require, "nvim-tree.api")
	if ok then
		api.tree.reload()
		return true
	end
	return false
end

function M.get_keymaps()
	return { normal = {}, visual = {}, shared = {} }
end

return M
