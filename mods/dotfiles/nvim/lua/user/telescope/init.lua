local status_ok, telescope = pcall(require, "telescope")
if not status_ok then
	vim.notify("telescope not found")
	return
end

local default_mappings = require("user.telescope.common").default_mappings
local picker_layout = require("user.telescope.common").picker_layout

telescope.setup({
	defaults = vim.tbl_extend("force", {
		path_display = { "truncate" },
		prompt_prefix = "⮕ ",
		selection_caret = "➤ ",
		-- path_display = { "smart" },
		mappings = default_mappings,
	}, picker_layout),

	layout_config = {},
	pickers = {
		find_files = picker_layout,
		buffers = picker_layout,
		git_files = picker_layout,
		live_grep = picker_layout,
		legendary = picker_layout,
		-- Default configuration for builtin pickers goes here:
		-- picker_name = {
		--   picker_config_key = value,
		--   ...
		-- }
		-- Now the picker_config_key will be applied every time you call this
		-- builtin picker
	},
	extensions = {
		file_browser = {
			hidden = true,
			theme = "dropdown",
			layout_config = {
				width = 0.98,
				height = 0.60,
			},
			-- open to current buffer location
			-- path = "%:p:h",
			grouped = true,
			previewer = false,
			hijack_netrw = true,
		},
	},
})
telescope.load_extension("file_browser")
telescope.load_extension("luasnip")

local M = {}

local _combine_modules = function(util_modules)
	for _, module in ipairs(util_modules) do
		for k, v in pairs(module) do
			M[k] = v
		end
	end
end

local find_files = require("user.telescope.find_files")
local search_files = require("user.telescope.search_files")
local git_files = require("user.telescope.git_files")
local git_search = require("user.telescope.git_search")
local compare = require("user.telescope.compare")
local project_commands = require("user.telescope.project_commands")
_combine_modules({
	find_files,
	search_files,
	git_files,
	git_search,
	compare,
	project_commands,
})

return M
