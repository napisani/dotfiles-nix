local M = {}

-- Dedicated venv for vocal.nvim with `requests` pre-installed.
-- Created by home-manager activation hook in uvx.nix.
-- Prepended to PATH so vocal.nvim always finds this python first,
-- regardless of any project-specific venv that may be active.
local VOCAL_VENV_BIN = vim.fn.expand("~/.local/share/nvim/vocal-venv/bin")

function M.setup()
	-- Prepend vocal venv to PATH before requiring vocal so its python3
	-- (with requests) is always discovered first by vocal.nvim's api module.
	if vim.fn.isdirectory(VOCAL_VENV_BIN) == 1 then
		vim.env.PATH = VOCAL_VENV_BIN .. ":" .. vim.env.PATH
	end

	local ok, vocal = pcall(require, "vocal")
	if not ok then
		vim.notify("vocal.nvim not found", vim.log.levels.WARN)
		return
	end

	vocal.setup({
		-- Uses OPENAI_API_KEY env var by default
		api_key = nil,

		-- Directory to save recordings
		recording_dir = os.getenv("HOME") .. "/recordings",

		-- Delete recordings after transcription
		delete_recordings = true,

		-- Disable default keymap (we set our own via which-key)
		keymap = nil,

		-- API configuration (OpenAI Whisper)
		api = {
			model = "whisper-1",
			language = nil, -- auto-detect
			response_format = "json",
			temperature = 0,
			timeout = 60,
		},
	})
end

function M.get_keymaps()
	return {
		normal = {
			{ "<leader>av", "<cmd>Vocal<cr>", desc = "(v)oice record toggle" },
		},
		visual = {
			{ "<leader>av", "<cmd>Vocal<cr>", desc = "(v)oice record (replace selection)" },
		},
		shared = {},
	}
end

return M
