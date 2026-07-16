-- Regression: common.capture_context("v") must reflect the *current* visual
-- selection, not whatever '< / '> were left over from a previous one.
--
-- '< / '> are only committed by Neovim when Visual mode is formally exited
-- (Esc, an operator, or a ":"-range command). Our visual-mode AI keymaps
-- (<leader>am, <leader>ae, <leader>a?, ...) are bound as plain Lua-function
-- callbacks, which Neovim invokes without going through any of those -- so
-- capture_context can run while still "in" Visual mode from the marks'
-- perspective, and reading '< / '> at that point returns stale text from
-- the last selection that was properly closed (sometimes the selection from
-- one <leader>am invocation prior). See BEHAVIOR.md / common.lua for detail.

local common = require("user.snacks.ai_actions.common")

local tmpfile = vim.fn.tempname() .. ".txt"
vim.fn.writefile({
	"line1",
	"line2 SELECTION_A",
	"line3 more A",
	"line4",
	"line5 SELECTION_B",
	"line6 more B",
	"line7",
	"abcdefghij",
}, tmpfile)
vim.cmd("edit " .. vim.fn.fnameescape(tmpfile))

local function select_lines_fresh(start_line, end_line)
	vim.cmd("normal! " .. tostring(start_line) .. "G")
	vim.cmd("normal! V")
	if end_line > start_line then
		vim.cmd("normal! " .. tostring(end_line - start_line) .. "j")
	end
end

-- Selection A, captured while still in Visual mode (the buggy code path read
-- unset '< / '> here and returned selection = nil).
select_lines_fresh(2, 3)
local ctx_a = common.capture_context("v")
assert(vim.fn.mode() == "V", "expected to still be in linewise Visual mode when capturing")
assert(
	ctx_a.selection == "line2 SELECTION_A\nline3 more A",
	"expected selection A while still in visual mode, got: " .. vim.inspect(ctx_a.selection)
)

-- Selection B, immediately after -- without an intervening Esc, since the
-- real keymap dispatch doesn't guarantee one either. Must reflect B, not a
-- stale mix of A's start and B's end.
vim.cmd("normal! \27") -- close out selection A cleanly before starting B
select_lines_fresh(5, 6)
local ctx_b = common.capture_context("v")
assert(
	ctx_b.selection == "line5 SELECTION_B\nline6 more B",
	"expected selection B, not stale selection A, got: " .. vim.inspect(ctx_b.selection)
)

vim.cmd("normal! \27")

-- Charwise, still in visual mode.
vim.cmd("normal! 8G0llv")
vim.cmd("normal! ll")
local ctx_charwise_live = common.capture_context("v")
assert(
	ctx_charwise_live.selection == "cde",
	"expected charwise live selection 'cde', got: " .. vim.inspect(ctx_charwise_live.selection)
)
vim.cmd("normal! \27")

-- Charwise, after Visual mode has already been exited (the '< / '> path
-- must keep working for callers that *do* trigger a proper exit first).
vim.cmd("normal! 8G0llv")
vim.cmd("normal! ll")
vim.cmd("normal! \27")
local ctx_charwise_post = common.capture_context("v")
assert(
	ctx_charwise_post.selection == "cde",
	"expected charwise post-exit selection 'cde', got: " .. vim.inspect(ctx_charwise_post.selection)
)

vim.fn.delete(tmpfile)

print("ai_actions_visual_selection_spec: ok")
