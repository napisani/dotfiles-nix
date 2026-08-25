--- Shared formatting for AI action entries.
--
-- Deliberately thin. Two things used to be duplicated here and drift apart:
--
--   1. The `@`-reference format. This module previously carried two emitters of
--      its own (`@path:42` and `@path lines 1-2`) while Vantage emitted a third
--      (`@path line 42` / `@path lines 1-2`). Vantage's prompt buffer is what
--      *parses* `@`-refs, so Vantage owns the format and everything here routes
--      through `vantage.format_reference`.
--   2. Entry assembly (ref + fenced selection + labeled body), which existed
--      both here and inline in `ai_actions.lua`. There is now one `build_entry`.
--
-- Context capture also lived here once. It is Vantage's `context()` now, which
-- additionally handles live visual selections that a plain Lua visual keymap
-- cannot get from the '< / '> marks.
---@module user.snacks.ai_actions.common

local M = {}

local function vantage()
	local ok, mod = pcall(require, "vantage")
	if not ok then
		vim.notify("vantage.nvim not found", vim.log.levels.ERROR)
		return nil
	end
	return mod
end

---The `@`-reference for a Vantage context's scope. Vantage relativizes the
---absolute path itself against the root it resolves refs against, so there is
---no local path rule to drift from it.
---@param ctx table Vantage context params (filePath, range)
---@return string|nil
local function context_reference(ctx)
	local v = vantage()
	if not v or not ctx or type(ctx.filePath) ~= "string" or ctx.filePath == "" then
		return nil
	end
	return v.format_reference({
		path = ctx.filePath,
		start_line = ctx.range and ctx.range.startLine,
		end_line = ctx.range and ctx.range.endLine,
	})
end

---One `@`-reference line for a picker/git reference item. Line bounds alone
---decide whether a range is emitted -- there is no `kind` discriminator, since
---it only restated what the bounds already say and silently dropped any item
---whose value was unrecognized.
---@param item { relative_path?: string, path?: string, start_line?: number, end_line?: number }
---@return string|nil
local function reference_line(item)
	local v = vantage()
	if not v or not item then
		return nil
	end
	return v.format_reference({
		path = item.relative_path or item.path,
		start_line = item.start_line,
		end_line = item.end_line,
	})
end

---Newline-joined `@`-reference lines for a list of reference items.
---@param spec { items?: table[] }|table a list wrapper, or a single item
---@return string
function M.format_reference_payload(spec)
	if not spec then
		return ""
	end

	local lines = {}
	for _, item in ipairs(spec.items or { spec }) do
		local line = reference_line(item)
		if line then
			table.insert(lines, line)
		end
	end

	if #lines == 0 then
		return ""
	end
	return table.concat(lines, "\n") .. "\n"
end

---Assemble one entry: the scope's `@`-ref, the selection fenced when asked for,
---then the body under its label. The ref format is Vantage's; the fence and
---labels are our presentation and stay here.
---@param ctx table Vantage context params (filePath, range, selectedText)
---@param opts { body?: string, body_label?: string }?
---@return string entry may be "" when there is nothing to say
function M.build_entry(ctx, opts)
	opts = opts or {}
	local parts = {}

	local ref = context_reference(ctx)
	if ref then
		table.insert(parts, ref)
	end

	-- Vantage's context is line-granular, so this is never a charwise selection.
	-- Label it by what it is, and rely on selectionSource rather than a mode flag
	-- threaded down from the keymap.
	local selected = ctx and ctx.selectionSource ~= "cursor" and ctx.selectedText or nil
	if selected and selected ~= "" then
		local range = ctx.range
		local heading = range and string.format("Lines %d-%d:", range.startLine, range.endLine) or "Lines:"
		table.insert(parts, heading .. "\n```\n" .. selected .. "\n```")
	end

	if opts.body and opts.body ~= "" then
		local label = opts.body_label
		if label and label ~= "" then
			table.insert(parts, label .. ":\n" .. opts.body)
		else
			table.insert(parts, opts.body)
		end
	end

	return table.concat(parts, "\n\n")
end

return M
