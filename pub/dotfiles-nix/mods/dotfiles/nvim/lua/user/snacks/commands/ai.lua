local ai_group = "AI > "
local commands = {
	{
		"lua require('user.plugins.ai.wiremux').focus_target()",
		description = ai_group .. "Focus Wiremux target",
	},
}

return {
	commands = commands,
}
