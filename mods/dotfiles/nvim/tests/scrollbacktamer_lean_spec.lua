-- The flag must be set before the config loads, so each case starts a child nvim with this config.
local init = vim.fs.joinpath(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))), "init.vim")

local function probe(extra_args)
	local cmd = { vim.v.progpath, "--headless", "-u", init }
	vim.list_extend(cmd, extra_args)
	vim.list_extend(cmd, {
		"-c",
		"lua io.stdout:write(vim.json.encode({"
			.. "lsp = package.loaded['user.lsp'] ~= nil,"
			.. "hop = pcall(require, 'hop'),"
			.. "cmd = vim.fn.exists(':Scrollbacktamer') == 2,"
			.. "plugin = pcall(require, 'scrollbacktamer') }))",
		"-c",
		"qa!",
	})
	local res = vim.system(cmd, { text = true }):wait()
	assert(res.code == 0, "child nvim failed: " .. (res.stderr or ""))
	return vim.json.decode(res.stdout:match("{.*}"))
end

local lean = probe({ "--cmd", "let g:scrollbacktamer = 1" })
assert(lean.lsp == false, "expected the scrollbacktamer flag to skip user.lsp")
assert(lean.hop, "expected hop to load in the scrollbacktamer viewer")
assert(lean.cmd, "expected :Scrollbacktamer to be registered")
assert(lean.plugin, "expected scrollbacktamer.nvim to load on require")

local normal = probe({})
assert(normal.lsp == true, "expected user.lsp to load without the scrollbacktamer flag")

print("scrollbacktamer_lean_spec: ok")
