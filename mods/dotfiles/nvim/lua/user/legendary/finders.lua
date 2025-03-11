
local package_group = "Find > "
local commands = {
	{
		":MasonUpdate",
		description = package_group .. "Mason Update",
	},
	{
		":MasonLog",
		description = package_group .. "View Mason log",
	},
	{
		":Mason",
		description = package_group .. "Mason",
	},
	{
		":Lazy",
		description = package_group .. "Lazy",
	},

	{
		":TSUpdate",
		description = package_group .. "TreeSitter Update",
	},
}

return {
	commands = commands,
}
