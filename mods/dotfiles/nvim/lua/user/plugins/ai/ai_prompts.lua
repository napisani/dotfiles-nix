local M = {}

M.defaults = {
	{ label = "Explain selection", value = "Explain the following selection in detail:\n{selection}" },
	{ label = "Review selection", value = "Review this selection for potential issues:\n{selection}" },
	{ label = "Summarize file", value = "Summarize the key points from {file}" },
	{ label = "Suggest improvements", value = "How can we improve {this}?" },
	{ label = "Generate tests", value = "Write tests that cover this code:\n{selection}" },
}

return M
