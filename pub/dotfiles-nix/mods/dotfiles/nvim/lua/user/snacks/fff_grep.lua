--- Custom snacks picker backed by fff.nvim's public Rust grep API.
--- Uses snacks UI (list + preview) with fff as the data source.
local M = {}

local utils = require("user.utils")

local DEFAULT_GREP_MODE = "regex"
local INDEX_WAIT_MS = 10000
local PAGE_SIZE = 200
local MAX_PAGES = 20

local notified = {}

local function notify_once(key, message, level)
	if notified[key] then
		return
	end
	notified[key] = true
	vim.schedule(function()
		vim.notify(message, level or vim.log.levels.WARN)
	end)
end

local function wait_for_index(fff, cwd)
	local ready = vim.wait(INDEX_WAIT_MS, function()
		local ok, result = pcall(fff.content_search, "", {
			mode = "plain",
			cwd = cwd,
			wait_for_index_ms = 0,
			page_size = 1,
		})
		return ok and result and (result.total_files or 0) > 0
	end, 50)

	if not ready then
		notify_once("fff-index-timeout", "fff grep: timed out waiting for index at " .. cwd, vim.log.levels.WARN)
	end

	return ready
end

local function make_snacks_item(cwd, item)
	local rel = item.relative_path
	if not rel then
		return nil
	end

	local line_nr = item.line_number or 1
	local col = (item.col or 0) + 1
	local content = tostring(item.line_content or "")

	return {
		text = rel .. ":" .. line_nr .. ":" .. col .. ": " .. content,
		file = rel,
		pos = { line_nr, col },
		line = content,
		cwd = cwd,
	}
end

local function content_search(fff, query, cwd, grep_mode, file_offset)
	local ok, result = pcall(fff.content_search, query, {
		mode = grep_mode,
		cwd = cwd,
		wait_for_index_ms = 0,
		file_offset = file_offset,
		page_size = PAGE_SIZE,
	})

	if not ok then
		notify_once("fff-content-search-failed", "fff grep failed: " .. tostring(result), vim.log.levels.ERROR)
		return nil
	end

	return result
end

--- Build a snacks finder function that calls fff's public content_search API.
--- The finder is called fresh on every keystroke (live = true).
---@param cwd string The working directory to index/search
---@param grep_mode? string Search mode: "plain", "regex", or "fuzzy"
---@return snacks.picker.finder
local function make_fff_grep_finder(cwd, grep_mode)
	grep_mode = grep_mode or DEFAULT_GREP_MODE
	local index_checked = false

	---@type snacks.picker.finder
	return function(_, ctx)
		local query = ctx.filter.search or ""
		if query == "" then
			return {}
		end

		local ok_fff, fff = pcall(require, "fff")
		if not ok_fff or type(fff.content_search) ~= "function" then
			notify_once(
				"fff-content-search-missing",
				"fff grep: public content_search API unavailable",
				vim.log.levels.ERROR
			)
			return {}
		end

		if not index_checked then
			index_checked = true
			if not wait_for_index(fff, cwd) then
				return {}
			end
		end

		local items = {} ---@type snacks.picker.finder.Item[]
		local file_offset = 0

		for _ = 1, MAX_PAGES do
			local result = content_search(fff, query, cwd, grep_mode, file_offset)
			if not result then
				return items
			end

			for _, item in ipairs(result.items or {}) do
				local snacks_item = make_snacks_item(cwd, item)
				if snacks_item then
					items[#items + 1] = snacks_item
				end
			end

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
