local api = vim.api
local config = vim.fn.getcwd() .. "/pub/dotfiles-nix/mods/dotfiles/nvim"
vim.opt.rtp:prepend(config)
for _, plugin in ipairs({ "plenary.nvim", "nvim-web-devicons", "diffview.nvim", "snacks.nvim" }) do
	vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end

local navigation = require("user.utils.edit_navigation")
assert(navigation.editing_win(api.nvim_get_current_tabpage()) == nil)
assert(package.loaded["diffview.lib"] == nil, "ordinary navigation must keep Diffview lazy")

vim.o.columns = 140
vim.o.lines = 50
vim.o.hidden = true
require("snacks").setup(require("user.snacks").opts)
vim.cmd("runtime plugin/diffview.lua")
require("user.plugins.git.diff").configure_diffview()

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
root = assert(vim.uv.fs_realpath(root))
local function git(...)
	local args = { "git", "-C", root }
	vim.list_extend(args, { ... })
	local output = vim.fn.system(args)
	assert(vim.v.shell_error == 0, output)
end
git("init", "-q")
vim.fn.writefile({ "old", "context", "last" }, root .. "/source.lua")
vim.fn.writefile({ "target", "second", "third" }, root .. "/target.lua")
git("add", ".")
git("-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "fixture")
vim.fn.writefile({ "changed", "context", "last" }, root .. "/source.lua")
vim.cmd.cd(root)
vim.cmd.edit(root .. "/source.lua")
local editing_tab = api.nvim_get_current_tabpage()
local editing_win = api.nvim_get_current_win()
vim.cmd.DiffviewOpen()
local diff_tab = api.nvim_get_current_tabpage()
local lib = require("diffview.lib")
local view = lib.get_current_view()
assert(
	vim.wait(5000, function()
		local win = view.cur_layout:get_main_win()
		return win
			and win:is_valid()
			and win.file
			and win.file:is_valid()
			and win.file.bufnr
			and api.nvim_buf_line_count(win.file.bufnr) == 3
	end),
	"Diffview failed to load fixture"
)
local diff_win = view.cur_layout:get_main_win().id
api.nvim_set_current_win(diff_win)
api.nvim_win_set_cursor(diff_win, { 2, 0 })
view.cur_layout:sync_scroll()
vim.wait(100)

local snapshot = {}
for _, win in ipairs(api.nvim_tabpage_list_wins(diff_tab)) do
	snapshot[win] = { buf = api.nvim_win_get_buf(win), cursor = api.nvim_win_get_cursor(win) }
end
local function assert_diff_unchanged()
	assert(lib.tabpage_to_view(diff_tab) == view, "Diffview must remain open")
	assert(#api.nvim_tabpage_list_wins(diff_tab) == vim.tbl_count(snapshot), "diff windows changed")
	for win, state in pairs(snapshot) do
		assert(api.nvim_win_get_buf(win) == state.buf, "diff buffer was replaced")
		assert(
			vim.deep_equal(api.nvim_win_get_cursor(win), state.cursor),
			"diff cursor moved in "
				.. win
				.. ": "
				.. vim.inspect(state.cursor)
				.. " -> "
				.. vim.inspect(api.nvim_win_get_cursor(win))
		)
	end
end

-- Visiting another editing tab must not replace the view's original destination.
vim.cmd.tabnew()
local other_tab = api.nvim_get_current_tabpage()
api.nvim_set_current_win(diff_win)
local Snacks = require("snacks")
local function picker(opts)
	local p = Snacks.picker.pick(vim.tbl_extend("force", {
		items = { { text = "target.lua", file = root .. "/target.lua", pos = { 2, 0 } } },
		format = "file",
		preview = "file",
	}, opts or {}))
	assert(
		vim.wait(3000, function()
			return p.shown and p:current() ~= nil
		end),
		"picker did not show"
	)
	return p
end

local cancelled = picker()
cancelled:action("cancel")
vim.wait(50)
assert(api.nvim_get_current_tabpage() == diff_tab, "cancel must stay in Diffview")
assert_diff_unchanged()

for _, action in ipairs({ "confirm", "edit_vsplit" }) do
	api.nvim_set_current_win(diff_win)
	local p = picker()
	p:action(action)
	assert(
		vim.wait(3000, function()
			return p.closed
				and api.nvim_get_current_tabpage() == editing_tab
				and api.nvim_buf_get_name(0) == root .. "/target.lua"
		end),
		"picker selection did not return to original tab: "
			.. vim.inspect({
				action = action,
				main = p.main,
				tab = api.nvim_get_current_tabpage(),
				buf = api.nvim_buf_get_name(0),
				closed = p.closed,
			})
	)
	assert(api.nvim_buf_get_name(0) == root .. "/target.lua")
	assert(api.nvim_win_get_cursor(0)[1] == 2)
	vim.wait(50)
	assert_diff_unchanged()
end

api.nvim_set_current_win(diff_win)
local automatic = Snacks.picker.pick({
	items = { { text = "target.lua", file = root .. "/target.lua", pos = { 2, 0 } } },
	format = "file",
	auto_confirm = true,
})
assert(
	vim.wait(3000, function()
		return automatic.closed
			and api.nvim_get_current_tabpage() == editing_tab
			and api.nvim_buf_get_name(0) == root .. "/target.lua"
	end),
	"auto-confirm must route even before picker windows are shown"
)
vim.wait(50)
assert_diff_unchanged()

api.nvim_set_current_win(diff_win)
local sidebar = picker({
	jump = { close = false },
	confirm = require("user.snacks.common").open_file_keep_picker_focus,
})
sidebar:action("confirm")
assert(
	vim.wait(3000, function()
		return sidebar.closed and api.nvim_get_current_tabpage() == editing_tab
	end),
	"persistent file pickers must navigate out of Diffview"
)
assert(api.nvim_win_get_cursor(0)[1] == 2)
vim.wait(50)
assert_diff_unchanged()

api.nvim_set_current_win(diff_win)
local quickfix = picker()
quickfix:action("qflist")
assert(api.nvim_get_current_tabpage() == editing_tab, "quickfix export must leave Diffview")
assert(vim.bo.buftype == "quickfix")
vim.cmd.cclose()
vim.wait(50)
assert_diff_unchanged()

local keymaps = require("user.lsp.keymaps")
local mapped = {}
for _, mapping in ipairs(keymaps.base) do
	mapped[mapping.key] = mapping.action
end
local originals = {
	get_clients = vim.lsp.get_clients,
	get_client_by_id = vim.lsp.get_client_by_id,
	buf_request_all = vim.lsp.buf_request_all,
}
local client = { id = 1, offset_encoding = "utf-16" }
vim.lsp.get_clients = function()
	return { client }
end
vim.lsp.get_client_by_id = function()
	return client
end
local pending
local expected_method
vim.lsp.buf_request_all = function(buf, method, params, callback)
	assert(buf == api.nvim_win_get_buf(diff_win), "LSP request must originate in the diff buffer")
	assert(method == expected_method)
	assert(params(client).position.line == 1, "LSP request must use the diff cursor")
	pending = callback
end
for key, method in pairs({
	gd = "definition",
	gD = "declaration",
	gy = "typeDefinition",
	gi = "implementation",
	gri = "implementation",
	gr = "references",
	grr = "references",
	grt = "typeDefinition",
}) do
	api.nvim_set_current_win(diff_win)
	expected_method = "textDocument/" .. method
	mapped[key]()
	assert(pending, "LSP callback not registered")
	api.nvim_set_current_tabpage(other_tab)
	pending({
		[1] = {
			result = {
				{
					uri = vim.uri_from_fname(root .. "/target.lua"),
					range = { start = { line = 1, character = 0 }, ["end"] = { line = 1, character = 3 } },
				},
			},
		},
	})
	pending = nil
	assert(api.nvim_get_current_tabpage() == editing_tab, key .. " must return to original editing tab")
	if method == "implementation" or method == "references" then
		assert(vim.bo.buftype == "quickfix", key .. " should show a location list")
		vim.cmd.lclose()
	else
		assert(api.nvim_buf_get_name(0) == root .. "/target.lua")
		assert(api.nvim_win_get_cursor(0)[1] == 2)
	end
	assert_diff_unchanged()
end
local category = require("user.scope.category")
category.select_scope("tests")
api.nvim_set_current_win(diff_win)
expected_method = "textDocument/references"
mapped.gr()
pending({
	[1] = {
		result = {
			{
				uri = vim.uri_from_fname(root .. "/target.lua"),
				range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
			},
		},
	},
})
assert(api.nvim_get_current_tabpage() == diff_tab, "filtered-empty results must not leave Diffview")
category.reset_all()
for name, fn in pairs(originals) do
	vim.lsp[name] = fn
end

api.nvim_set_current_tabpage(other_tab)
local ordinary = picker()
ordinary:action("confirm")
assert(vim.wait(3000, function()
	return ordinary.closed and api.nvim_buf_get_name(0) == root .. "/target.lua"
end))
assert(api.nvim_get_current_tabpage() == other_tab, "ordinary picker navigation must stay in its tab")
vim.wait(50)
assert_diff_unchanged()

-- A surviving file window is preferred over a focused location-list window.
api.nvim_set_current_win(editing_win)
vim.fn.setloclist(0, { { filename = root .. "/target.lua", lnum = 1 } })
vim.cmd.lopen()
api.nvim_set_current_win(diff_win)
local destination = navigation.editing_win(diff_tab)
assert(vim.bo[api.nvim_win_get_buf(destination)].buftype == "")

-- Closed origins fall back to a surviving normal tab, never another diff window.
api.nvim_set_current_tabpage(editing_tab)
vim.cmd.tabclose()
api.nvim_set_current_win(diff_win)
assert(api.nvim_win_get_tabpage(navigation.editing_win(diff_tab)) == other_tab)
api.nvim_set_current_tabpage(other_tab)
vim.cmd.tabclose()
api.nvim_set_current_win(diff_win)
local replacement = navigation.editing_win(diff_tab)
assert(api.nvim_win_get_tabpage(replacement) ~= diff_tab, "last remaining diff tab needs a new editing tab")
assert_diff_unchanged()

api.nvim_set_current_win(diff_win)
vim.cmd.DiffviewClose()
vim.fn.delete(root, "rf")
print("diffview_navigation_spec: ok")
