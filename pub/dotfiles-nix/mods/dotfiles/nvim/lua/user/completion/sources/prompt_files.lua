---@module "user.completion.sources.prompt_files"

local source = {}

local trigger = "@"

local function current_context(ctx)
	local bufnr = ctx and ctx.bufnr or vim.api.nvim_get_current_buf()
	local row, col

	local cursor = ctx and ctx.cursor
	if type(cursor) == "table" then
		if cursor.line then
			row = cursor.line
			col = cursor.character
		else
			row = cursor[1] and cursor[1] - 1 or nil
			col = cursor[2]
		end
	end

	if not row or not col then
		local win_cursor = vim.api.nvim_win_get_cursor(0)
		row = win_cursor[1] - 1
		col = win_cursor[2]
	end

	return bufnr, row, col, ctx and ctx.line
end

local function is_prompt_builder(bufnr)
	local ok, value = pcall(vim.api.nvim_buf_get_var, bufnr, "prompt_builder")
	return ok and value == true
end

function source.file_token_range(ctx)
	local bufnr, row, col, context_line = current_context(ctx)
	local line = context_line or vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
	local prefix = line:sub(1, col)
	local token_start = prefix:match(".*()" .. vim.pesc(trigger) .. "[%w%._%-%/%\\]*$")

	if not token_start then
		return nil
	end

	return bufnr,
		{
			start = { line = row, character = token_start - 1 },
			["end"] = { line = row, character = col },
		}
end

local function fallback_files(root, opts)
	local files = {}
	local max_entries = opts.max_entries or 5000
	local skip = {
		[".git"] = true,
		["node_modules"] = true,
		[".direnv"] = true,
	}

	for path, type in vim.fs.dir(root, { depth = opts.max_depth or math.huge }) do
		local skipped = false
		for part in path:gmatch("[^/\\]+") do
			if skip[part] then
				skipped = true
				break
			end
		end

		if type == "file" and not skipped then
			table.insert(files, path)
			if #files >= max_entries then
				break
			end
		end
	end

	table.sort(files)
	return files
end

function source.list_files(root, opts)
	opts = opts or {}
	local max_entries = opts.max_entries or 5000

	if vim.fn.executable("rg") ~= 1 then
		return fallback_files(root, opts)
	end

	local result = vim.system(
		{ "rg", "--files", "--hidden", "--glob", "!.git/*", "--glob", "!node_modules/*" },
		{ cwd = root, text = true }
	):wait()
	if result.code ~= 0 then
		return {}
	end

	local files = {}
	for line in vim.gsplit(result.stdout or "", "\n", { plain = true, trimempty = true }) do
		if line ~= "" then
			table.insert(files, line)
			if #files >= max_entries then
				break
			end
		end
	end

	table.sort(files)
	return files
end

function source.new(opts)
	local self = setmetatable({}, { __index = source })
	self.opts = opts or {}
	return self
end

function source:enabled()
	return is_prompt_builder(vim.api.nvim_get_current_buf())
end

function source:get_trigger_characters()
	return { trigger }
end

function source:get_completions(ctx, callback)
	local bufnr, range = source.file_token_range(ctx)
	if not range or not is_prompt_builder(bufnr) then
		callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
		return
	end

	local items = {}
	for index, path in ipairs(source.list_files(self.opts.root or vim.fn.getcwd(), self.opts)) do
		local insert_text = trigger .. path
		table.insert(items, {
			label = insert_text,
			kind = vim.lsp.protocol.CompletionItemKind.File,
			detail = "Relative file",
			filterText = path .. " " .. insert_text,
			sortText = string.format("%04d_%s", index, path),
			textEdit = {
				newText = insert_text,
				range = range,
			},
			insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
			documentation = {
				kind = "markdown",
				value = "`" .. insert_text .. "`",
			},
		})
	end

	callback({
		items = items,
		is_incomplete_backward = false,
		is_incomplete_forward = false,
	})
end

return source
