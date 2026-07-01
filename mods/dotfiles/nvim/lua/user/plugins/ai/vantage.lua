local M = {}

local unpack = table.unpack or unpack

local function with_vantage(method, ...)
	local args = { ... }
	return function()
		local ok, vantage = pcall(require, "vantage")
		if not ok then
			vim.notify("vantage.nvim not found", vim.log.levels.WARN)
			return
		end

		local fn = vantage[method]
		if type(fn) ~= "function" then
			vim.notify("vantage.nvim has no public function " .. method, vim.log.levels.WARN)
			return
		end

		fn(unpack(args))
	end
end

local function command_opts(args)
	args = args or ""
	local fargs = {}
	for part in args:gmatch("%S+") do
		table.insert(fargs, part)
	end
	return {
		args = args,
		fargs = fargs,
		range = 0,
	}
end

local function visual_opts(args)
	local start_line = vim.fn.getpos("'<")[2]
	local end_line = vim.fn.getpos("'>")[2]
	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local opts = command_opts(args)
	opts.range = 2
	opts.line1 = start_line
	opts.line2 = end_line
	return opts
end

M.opts = {
	agent = {
		provider = "anthropic",
		model = "claude-haiku-4-5",
		options = {
			reasoning = "minimal",
		},
	},
}

function M.setup()
	-- Vantage is configured lazily by the plugin spec when require("vantage")
	-- first loads vantage.nvim.
end

function M.configure(opts)
	local ok, vantage = pcall(require, "vantage")
	if not ok then
		vim.notify("vantage.nvim not found", vim.log.levels.WARN)
		return
	end

	vantage.setup(opts or M.opts)
end

function M.get_keymaps()
	return {
		shared = {
			{ "<leader>v", group = "Vantage" },
			{ "<leader>vb", group = "Vantage agent" },
		},
		normal = {
			{ "<leader>va", with_vantage("annotate", command_opts()), desc = "annotate line" },
			{ "<leader>vA", with_vantage("annotate", command_opts("visible")), desc = "annotate visible" },
			{ "<leader>vx", with_vantage("clear_annotations"), desc = "clear annotations" },
			{ "<leader>vl", with_vantage("prompt_lens", "learning"), desc = "set lens" },
			{ "<leader>vL", with_vantage("clear_lens"), desc = "clear lens" },
			{ "<leader>ve", with_vantage("edit", command_opts()), desc = "edit line" },
			{ "<leader>vE", with_vantage("explain", command_opts()), desc = "explain line" },
			{ "<leader>v?", with_vantage("question", command_opts()), desc = "ask question" },
			{ "<leader>vf", with_vantage("search", command_opts()), desc = "search project" },
			{ "<leader>vw", with_vantage("load_walkthrough"), desc = "load walkthrough" },
			{ "<leader>vo", with_vantage("session_output"), desc = "session output" },
			{ "<leader>vs", with_vantage("status"), desc = "status" },
			{ "<leader>vbc", with_vantage("agent_cancel"), desc = "cancel agent request" },
			{ "<leader>vbr", with_vantage("agent_reset"), desc = "reset agent session" },
		},
		visual = {
			{ "<leader>va", function() with_vantage("annotate", visual_opts())() end, desc = "annotate selection" },
			{ "<leader>ve", function() with_vantage("edit", visual_opts())() end, desc = "edit selection" },
			{ "<leader>vE", function() with_vantage("explain", visual_opts())() end, desc = "explain selection" },
			{ "<leader>v?", function() with_vantage("question", visual_opts())() end, desc = "ask about selection" },
			{ "<leader>vf", function() with_vantage("search", visual_opts())() end, desc = "search from selection" },
		},
	}
end

return M
