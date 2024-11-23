local package_group = "Package Manager > "
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
}

return {
	commands = commands,
}
