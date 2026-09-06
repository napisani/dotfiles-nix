local M = {}

-- Nix-provided Python + requests, linked by Home Manager in neovim.nix.
-- Keep this ahead of project interpreters, which may not have requests.
local VOCAL_PYTHON_BIN = vim.fn.expand("~/.local/share/nvim/vocal-python/bin")

function M.setup()
	-- The plugin discovers python3 from PATH when launching its uploader.
	if vim.fn.isdirectory(VOCAL_PYTHON_BIN) == 1 then
		vim.env.PATH = VOCAL_PYTHON_BIN .. ":" .. vim.env.PATH
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

		-- Disable default keymap (we set our own via which-key).
		-- `nil` does not override vocal.nvim's default during table merge.
		keymap = false,

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

-- Voice toggle lives on `<leader>av` in `ai.wiremux` (see BEHAVIOR.md).
function M.get_keymaps()
	return {
		normal = {},
		visual = {},
		shared = {},
	}
end

return M
