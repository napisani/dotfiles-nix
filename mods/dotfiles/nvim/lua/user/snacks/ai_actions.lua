local common = require("user.snacks.ai_actions.common")

local M = {}

-- Collect freeform text in Vantage's prompt buffer, then append the captured
-- scope plus that text to Vantage's composition buffer. Shared code path for
-- `<leader>am`, `<leader>ae`, and `<leader>a?`.
--
-- Vantage owns context capture (including live visual-selection handling, which
-- plain Lua visual keymaps like ours cannot get from the '< / '> marks), the
-- multi-line prompt surface with @ref/skill expansion, the composition buffer,
-- and entry separation. We own only the entry layout.
--
-- Whether a selection block appears is decided by Vantage's `selectionSource`,
-- not by a mode flag from the keymap.
--
-- opts: body_label (required), optional input_prompt used as the prompt float's
-- title, optional done_notify
function M.append_context_to_composition(opts)
	opts = opts or {}
	local body_label = opts.body_label
	if not body_label or body_label == "" then
		vim.notify("append_context_to_composition: body_label is required", vim.log.levels.ERROR)
		return
	end

	local ok_vantage, vantage = pcall(require, "vantage")
	if not ok_vantage then
		vim.notify("vantage.nvim not found", vim.log.levels.ERROR)
		return
	end

	local ctx = vantage.context()
	if not ctx.filePath or ctx.filePath == "" then
		vim.notify("Current buffer has no file name", vim.log.levels.WARN)
		return
	end

	vantage.prompt({
		kind = "composition-entry",
		title = opts.input_prompt or body_label,
		params = ctx,
		on_submit = function(text)
			local entry = common.build_entry(ctx, {
				body = text,
				body_label = body_label,
			})
			if entry == "" then
				return
			end
			vantage.compose_append(entry)
			vim.notify(opts.done_notify or "Appended to Vantage composition", vim.log.levels.INFO)
		end,
	})
end

-- Like `<leader>ae` / `<leader>a?`, but titled + labelled `Instructions`.
-- opts: optional input_prompt, body_label
function M.append_memo_to_composition(opts)
	opts = opts or {}
	return M.append_context_to_composition({
		input_prompt = opts.input_prompt or "Instructions",
		body_label = opts.body_label or "Instructions",
		done_notify = "Context appended to Vantage composition",
	})
end

return M
