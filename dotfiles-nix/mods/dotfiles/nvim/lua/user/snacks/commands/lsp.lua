local package_group = "LSP > "
local commands = {
	{
		":LspInfo",
		description = package_group .. "Lsp Info",
	},
}

return {
	commands = commands,
}
