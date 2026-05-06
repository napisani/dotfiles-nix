---@module "user.completion.sources.skills"

local source = {}

local ai_skills = require("user.snacks.ai_skills")

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

local function skill_token_range(ctx)
	local bufnr, row, col, context_line = current_context(ctx)
	local line = context_line or vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
	local prefix = line:sub(1, col)
	local trigger = ai_skills.completion_trigger()
	local token_start = prefix:match(".*()" .. vim.pesc(trigger) .. "[%w_.-]*$")

	if not token_start then
		return nil
	end

	return bufnr,
		{
			start = { line = row, character = token_start - 1 },
			["end"] = { line = row, character = col },
		}
end

function source.new(opts)
	local self = setmetatable({}, { __index = source })
	self.opts = opts or {}
	return self
end

function source:enabled()
	return ai_skills.is_prompt_builder(vim.api.nvim_get_current_buf())
end

function source:get_trigger_characters()
	return ai_skills.completion_trigger_characters()
end

function source:get_completions(ctx, callback)
	local provider = ai_skills.current_provider()
	local bufnr, range = skill_token_range(ctx)
	if not range or not ai_skills.is_prompt_builder(bufnr) then
		callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
		return
	end

	local items = {}
	for index, skill in ipairs(ai_skills.list(self.opts)) do
		local insert_text = ai_skills.skill_invocation(skill, { provider = provider })
		local draft_text = ai_skills.completion_trigger() .. skill.name
		table.insert(items, {
			label = insert_text,
			kind = vim.lsp.protocol.CompletionItemKind.Text,
			detail = skill.description ~= "" and skill.description or "Skill",
			filterText = draft_text .. " " .. insert_text .. " " .. skill.name,
			sortText = string.format("%04d_%s", index, skill.name),
			textEdit = {
				newText = insert_text,
				range = range,
			},
			insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
			documentation = skill.description ~= "" and {
				kind = "markdown",
				value = string.format("**%s**\n\n%s\n\n`%s`", insert_text, skill.description, skill.path),
			} or nil,
		})
	end

	callback({
		items = items,
		is_incomplete_backward = false,
		is_incomplete_forward = false,
	})
end

return source
