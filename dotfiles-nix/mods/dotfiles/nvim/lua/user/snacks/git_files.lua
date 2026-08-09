local utils = require("user.utils")
local common = require("user.snacks.common")
local Snacks = require("snacks")

local M = {}

local function normalize_changed_files(file_list)
	local seen = {}
	local result = {}

	for _, file in ipairs(file_list or {}) do
		file = vim.trim(file or "")
		file = file:gsub("^%./", "")
		if file ~= "" and not seen[file] then
			seen[file] = true
			table.insert(result, file)
		end
	end

	table.sort(result)
	return result
end

local function build_file_tree_items(file_list, cwd)
	local files = normalize_changed_files(file_list)
	local root = { children = {}, dir = true }

	local function ensure_child(parent, name, rel_path, is_dir)
		parent.children[name] = parent.children[name]
			or {
				name = name,
				rel_path = rel_path,
				children = {},
				dir = is_dir,
			}

		parent.children[name].dir = parent.children[name].dir or is_dir
		return parent.children[name]
	end

	for _, rel_path in ipairs(files) do
		local parent = root
		local path_parts = vim.split(rel_path, "/", { plain = true, trimempty = true })

		for index, part in ipairs(path_parts) do
			local path_prefix = table.concat(vim.list_slice(path_parts, 1, index), "/")
			local is_dir = index < #path_parts
			parent = ensure_child(parent, part, path_prefix, is_dir)
		end
	end

	local items = {}

	local function flatten(node, parent_item)
		local children = vim.tbl_values(node.children)
		table.sort(children, function(left, right)
			if left.dir ~= right.dir then
				return left.dir
			end
			return left.name < right.name
		end)

		for index, child in ipairs(children) do
			local item = {
				text = child.rel_path,
				file = cwd .. "/" .. child.rel_path,
				dir = child.dir,
				open = child.dir,
				parent = parent_item,
				last = index == #children,
				sort = child.rel_path,
			}

			table.insert(items, item)

			if child.dir then
				flatten(child, item)
			end
		end
	end

	flatten(root, nil)
	return items
end

local function changed_files_tree(file_list, opts)
	opts = opts or {}
	local cwd = opts.cwd or utils.get_root_dir()
	local items = build_file_tree_items(file_list, cwd)

	if #items == 0 then
		vim.notify("No changed files", vim.log.levels.INFO)
		return
	end

	return Snacks.picker.pick(vim.tbl_extend("force", opts, {
		source = "changed files tree",
		cwd = cwd,
		items = items,
		format = "file",
		focus = "list",
		auto_close = false,
		jump = { close = false },
		layout = { preset = "sidebar", preview = false },
		win = {
			input = {
				keys = {
					["<Esc>"] = false,
				},
			},
			list = {
				keys = {
					["<Esc>"] = false,
					l = "confirm",
					o = "confirm",
				},
			},
			preview = {
				keys = {
					["<Esc>"] = false,
				},
			},
		},
		formatters = {
			file = { filename_only = true },
		},
		matcher = {
			sort_empty = false,
			fuzzy = true,
		},
		confirm = function(picker, item)
			common.open_file_keep_picker_focus(picker, item)
		end,
	}))
end

function M.git_changed_files(opts)
	opts = opts or {}
	local cwd = utils.get_root_dir()
	local file_list = utils.git_changed_files().get_files()
	local all_opts = vim.tbl_extend("force", opts, {
		cwd = cwd,
		items = file_list,
	})
	return common.file_list_to_picker(file_list, all_opts)
end

function M.git_changed_files_tree(opts)
	opts = opts or {}
	local cwd = utils.get_root_dir()
	return changed_files_tree(
		utils.git_changed_files().get_files(),
		vim.tbl_extend("force", opts, {
			cwd = cwd,
			title = "Local Changes",
		})
	)
end

M.git_changed_cmp_base_branch = function(opts)
	opts = opts or {}
	local cwd = utils.get_root_dir()
	opts.cwd = cwd

	local base_branch = utils.get_git_ref()
	-- Run git from the project root so paths are relative to root regardless
	-- of which subdirectory Neovim was started in.
	local cmd = { "git", "-C", cwd }
	local args = utils.git_changed_in_branch().get_git_args(base_branch)
	for _, arg in ipairs(args) do
		table.insert(cmd, arg)
	end

	local files_list = vim.fn.systemlist(cmd)
	local all_opts = vim.tbl_extend("force", opts, {
		items = files_list,
		cwd = cwd,
	})
	return common.file_list_to_picker(files_list, all_opts)
end

M.git_changed_cmp_base_branch_tree = function(opts)
	opts = opts or {}
	local cwd = utils.get_root_dir()
	local base_branch = utils.get_git_ref()
	local files_list = utils.git_changed_in_branch().get_files(base_branch)

	return changed_files_tree(
		files_list,
		vim.tbl_extend("force", opts, {
			cwd = cwd,
			title = "Changes vs " .. base_branch,
		})
	)
end

M.git_conflicted_files = function(opts)
	opts = opts or {}
	local cwd = utils.get_root_dir()
	opts.cwd = cwd

	-- Run git from the project root so paths are relative to root.
	local cmd = { "git", "-C", cwd }
	local args = utils.git_conflicted_files().get_git_args()
	for _, arg in ipairs(args) do
		table.insert(cmd, arg)
	end

	local files_list = vim.fn.systemlist(cmd)
	local all_opts = vim.tbl_extend("force", opts, {
		items = files_list,
		cwd = cwd,
	})
	return common.file_list_to_picker(files_list, all_opts)
end

return M
