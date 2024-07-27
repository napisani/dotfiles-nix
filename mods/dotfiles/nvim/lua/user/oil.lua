local oil_ok, oil = pcall(require, "oil")
if not oil_ok then
	vim.notify("oil not found")
	return
end

oil.setup({
	-- display = {
	-- 	-- open_fn = function()
	-- 	-- 	return require("packer.util").float({ border = "rounded" })
	-- 	-- end,
	-- },
})
