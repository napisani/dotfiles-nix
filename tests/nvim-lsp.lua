local source, plugins, case_file = assert(arg[1]), assert(arg[2]), assert(arg[3])
local case = vim.json.decode(table.concat(vim.fn.readfile(case_file), "\n"))
vim.opt.runtimepath:append(plugins .. "/nvim-lspconfig")
vim.opt.runtimepath:append(plugins .. "/efmls-configs-nvim")
vim.opt.runtimepath:append(plugins .. "/plenary.nvim")
vim.opt.runtimepath:prepend(source)
require("user.runtime")
vim.cmd.cd(case.root)
vim.cmd.edit(case.file)
vim.bo.filetype = case.filetype
assert(vim.tbl_contains(require("user.lsp.registry").servers(), case.name), "server excluded by project policy")
local config = vim.lsp.config[case.name]
assert(config and config.cmd, "missing authored or upstream server configuration")
local executable
local start_rpc = vim.lsp.rpc.start
vim.lsp.rpc.start = function(command, ...)
	executable = vim.fn.exepath(command[1])
	if case.owner == "nix" then
		assert(case.name == "nil_ls")
		assert(vim.uv.fs_realpath(executable):find("/nix/store/", 1, true) == 1, "nil is not Nix-owned")
	else
		assert(executable:find("/mise/", 1, true), "server is not selected through mise: " .. executable)
	end
	return start_rpc(command, ...)
end
vim.lsp.enable(case.name)
local client
assert(
	vim.wait(30000, function()
		for _, candidate in ipairs(vim.lsp.get_clients({ bufnr = 0, name = case.name })) do
			if candidate.initialized then
				client = candidate
				return true
			end
		end
		return false
	end, 25),
	"server did not attach: " .. case.name
)
local buffer = vim.api.nvim_get_current_buf()
local report = {
	name = case.name,
	owner = case.owner or "mise",
	executable = executable,
	attached = vim.lsp.buf_is_attached(buffer, client.id),
	configured = require("user.lsp.registry").configured,
}
assert(report.attached, "initialized client is not attached to the fixture buffer")
if case.name == "efm" then
	local response = client:request_sync("textDocument/formatting", {
		textDocument = { uri = vim.uri_from_bufnr(buffer) },
		options = { tabSize = 2, insertSpaces = true },
	}, 10000, buffer)
	assert(
		response and not response.err and response.result and #response.result > 0,
		"EFM produced no formatting edits"
	)
	vim.lsp.util.apply_text_edits(response.result, buffer, client.offset_encoding)
	assert(vim.api.nvim_buf_get_lines(buffer, 0, 1, false)[1] == "local value = 1", "EFM did not run StyLua")
	report.formatter = "stylua"
elseif case.name == "ruff" then
	assert(
		vim.wait(10000, function()
			return #vim.diagnostic.get(buffer) > 0
		end, 25),
		"Ruff published no diagnostics"
	)
	report.diagnostics = #vim.diagnostic.get(buffer)
elseif case.name == "eslint" or case.name == "tailwindcss" then
	assert(next(client.server_capabilities), "empty server capabilities")
else
	local response
	assert(
		vim.wait(15000, function()
			response = client:request_sync("textDocument/documentSymbol", {
				textDocument = { uri = vim.uri_from_bufnr(buffer) },
			}, 2000, buffer)
			return response and not response.err and response.result and #response.result > 0
		end, 100),
		"server produced no document symbols: " .. vim.inspect(response)
	)
	report.symbols = #response.result
end
vim.fn.writefile({ vim.json.encode(report) }, case.report)
client:stop()
assert(
	vim.wait(5000, function()
		return client:is_stopped()
	end, 25),
	"server did not stop"
)
print(case.name .. " attached through " .. report.owner)
