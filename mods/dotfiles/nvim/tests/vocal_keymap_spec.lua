local original_loaded = package.loaded.vocal
local original_preload = package.preload.vocal
local captured_config = nil

package.loaded.vocal = nil
package.preload.vocal = function()
	return {
		setup = function(config)
			captured_config = config
		end,
	}
end

local ok, err = xpcall(function()
	require("user.plugins.ai.vocal").setup()
end, debug.traceback)

package.loaded.vocal = original_loaded
package.preload.vocal = original_preload

if not ok then
	error(err, 0)
end

assert(captured_config, "expected vocal.setup to be called")
assert(captured_config.keymap == false, "expected vocal default <leader>v keymap to be disabled")

print("vocal_keymap_spec: ok")
