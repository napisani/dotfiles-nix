local data = vim.env.XDG_DATA_HOME
if not data or data == "" then
	data = vim.env.HOME .. "/.local/share"
end

-- GUI clients do not inherit shell activation; keep project-aware shims first.
local shims = data .. "/mise/shims"
local paths = { shims }
for _, path in ipairs(vim.split(vim.env.PATH or "", ":", { plain = true, trimempty = true })) do
	if path ~= shims then
		table.insert(paths, path)
	end
end
vim.env.PATH = table.concat(paths, ":")
vim.g.python3_host_prog = data .. "/dotfiles/nvim-python/bin/python"
vim.g.loaded_ruby_provider = 0
