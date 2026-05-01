--- Custom snacks picker backed by fff.nvim's Rust grep engine.
--- Uses snacks UI (list + preview) with fff as the data source instead of rg.
local M = {}

local utils = require("user.utils")
local DEFAULT_GREP_MODE = "regex"

--- Build a snacks finder function that calls fff's Rust grep engine.
--- The finder is called fresh on every keystroke (live = true).
---@param cwd string The working directory (fff's base_path must match this)
---@param grep_mode? string Search mode: "plain", "regex", or "fuzzy"
---@return snacks.picker.finder
local function make_fff_grep_finder(cwd, grep_mode)
	grep_mode = grep_mode or DEFAULT_GREP_MODE

	---@type snacks.picker.finder
	return function(opts, ctx)
		local query = ctx.filter.search or ""

		-- Return empty immediately for blank queries
		if query == "" then
			return {}
		end

		local ok_grep, fff_grep = pcall(require, "fff.grep")
		if not ok_grep then
			return {}
		end

		-- fff requires the file picker to be initialized before grep.search() works.
		-- ensure_initialized() is idempotent — safe to call on every search.
		local ok_core, fff_core = pcall(require, "fff.core")
		if ok_core then
			pcall(fff_core.ensure_initialized)
		end

		-- Ensure fff is indexing the right directory (may differ from where nvim started).
		local ok_main, fff_main = pcall(require, "fff")
		if ok_main and fff_main.change_indexing_directory then
			pcall(fff_main.change_indexing_directory, cwd)
		end

		-- Use the cwd passed into the closure as the base path for resolving relative paths.
		local base_path = cwd

		-- Collect all pages of results (fff paginates by file offset)
		local items = {} ---@type snacks.picker.finder.Item[]
		local file_offset = 0
		local page_size = 200
		local max_iterations = 20 -- safety cap

		for _ = 1, max_iterations do
			local ok_search, result = pcall(fff_grep.search, query, file_offset, page_size, nil, grep_mode)
			if not ok_search or not result then
				break
			end

			local raw_items = result.items or {}
			for _, item in ipairs(raw_items) do
				-- item fields (from fff/grep/grep_renderer.lua):
				--   item.relative_path  (string, relative to fff base_path)
				--   item.line_number    (number, 1-indexed)
				--   item.col            (number, 0-indexed column)
				--   item.line_content   (string, the matched line text)
				--   item.match_ranges   (table, list of {start, end} byte ranges)

				local rel = item.relative_path
				if not rel then
					goto continue
				end

				local line_nr = item.line_number or 1
				local col = item.col or 0
				local content = tostring(item.line_content or "")

				-- Build display text: "file:line:col: content"
				local display = rel .. ":" .. line_nr .. ":" .. (col + 1) .. ": " .. content

				-- snacks util.path() builds the full path as: cwd .. "/" .. file
				-- So item.file must be relative (not absolute) when item.cwd is set.
				---@type snacks.picker.finder.Item
				local snacks_item = {
					text = display,
					file = rel, -- relative path; snacks combines with cwd to get absolute
					pos = { line_nr, col + 1 }, -- col is 0-indexed from fff; pos uses 1-indexed
					line = content,
					cwd = base_path,
				}

				items[#items + 1] = snacks_item

				::continue::
			end

			-- Paginate: next_file_offset = 0 means no more results (fff convention).
			-- A non-zero value is the offset to pass for the next page.
			local next_offset = result.next_file_offset or 0
			if next_offset == 0 then
				break
			end
			file_offset = next_offset
		end

		return items
	end
end

--- Open a snacks live-grep picker backed by fff's Rust grep engine.
--- Uses snacks UI (list, preview, keybindings) with fff as the search source.
---@param opts? snacks.picker.Config|{fff_grep_mode?: string}
function M.live_grep_from_root(opts)
	local ok_snacks, Snacks = pcall(require, "snacks")
	if not ok_snacks then
		vim.notify("snacks not available", vim.log.levels.WARN)
		return
	end

	opts = opts or {}
	local grep_mode = opts.fff_grep_mode or DEFAULT_GREP_MODE
	local picker_opts = vim.tbl_extend("force", {}, opts)
	picker_opts.fff_grep_mode = nil

	local cwd = utils.get_root_dir()

	local all_opts = vim.tbl_extend("force", picker_opts, {
		finder = make_fff_grep_finder(cwd, grep_mode),
		format = "file",
		live = true,
		supports_live = true,
		need_search = true,
		cwd = cwd,
		title = "Live Grep (fff)",
	})

	return Snacks.picker(all_opts)
end

return M
