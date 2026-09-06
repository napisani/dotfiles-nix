-- Public seams: our Vocal setup -> the plugin's setup and Python subprocess.
-- The real plugin resolves python3 from PATH before launching its uploader.
-- No network, credentials, recording devices, or installed plugins are needed.
local initialized = false
package.preload["vocal"] = function()
	return {
		setup = function(options)
			assert(options.api.model == "whisper-1", "transcription model changed")
			local result = vim.system({
				"python3",
				"-c",
				"import requests; print('vocal requests available')",
			}, { text = true }):wait()
			assert(result.code == 0, result.stderr)
			assert(result.stdout == "vocal requests available\n", result.stdout)
			initialized = true
		end,
	}
end

dofile(arg[1]).setup()
assert(initialized, "Vocal plugin setup was not reached")
print("Vocal uses its declared Python, even ahead of a project interpreter")
