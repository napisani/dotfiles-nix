local M = {}

local function notify(message, level)
	vim.notify("[mermaid] " .. message, level or vim.log.levels.INFO)
end

function M.output_path_for(input_path)
	return vim.fn.fnamemodify(input_path, ":r") .. ".svg"
end

function M.viewer_path_for(svg_path)
	return vim.fn.fnamemodify(svg_path, ":r") .. ".viewer.html"
end

local function file_stat(path)
	if not path or path == "" then
		return nil
	end
	local uv = vim.uv or vim.loop
	local stat = uv.fs_stat(path)
	if stat ~= nil and stat.type == "file" then
		return stat
	end
	return nil
end

local function is_file(path)
	return file_stat(path) ~= nil
end

local function pattern_escape(value)
	return value:gsub("([^%w])", "%%%1")
end

local function html_escape(value)
	return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

local function was_rendered(stat, rendered_after)
	return stat ~= nil and stat.size > 0 and (rendered_after == nil or stat.mtime.sec >= rendered_after)
end

function M.rendered_outputs_for(output_path, rendered_after)
	local outputs = {}
	local direct_stat = file_stat(output_path)
	if was_rendered(direct_stat, rendered_after) then
		table.insert(outputs, output_path)
	end

	local dir = vim.fn.fnamemodify(output_path, ":h")
	local stem = vim.fn.fnamemodify(output_path, ":t:r")
	local extension = vim.fn.fnamemodify(output_path, ":e")
	if extension == "" then
		return outputs
	end

	local numbered_outputs = {}
	local numbered_name_pattern = "^" .. pattern_escape(stem) .. "%-%d+%." .. pattern_escape(extension) .. "$"
	local uv = vim.uv or vim.loop
	local handle = uv.fs_scandir(dir)
	if handle == nil then
		return outputs
	end

	while true do
		local name, file_type = uv.fs_scandir_next(handle)
		if name == nil then
			break
		end

		if file_type == "file" and name:match(numbered_name_pattern) then
			local path = dir .. "/" .. name
			local stat = file_stat(path)
			if was_rendered(stat, rendered_after) then
				table.insert(numbered_outputs, path)
			end
		end
	end

	table.sort(numbered_outputs)
	vim.list_extend(outputs, numbered_outputs)
	return outputs
end

local function exepath(command)
	local path = vim.fn.exepath(command)
	if path ~= "" then
		return path
	end
	return nil
end

function M.find_browser()
	local uv = vim.uv or vim.loop
	local candidates = {
		vim.env.PUPPETEER_EXECUTABLE_PATH,
		exepath("chromium"),
		exepath("chromium-browser"),
		exepath("google-chrome-stable"),
		exepath("google-chrome"),
		exepath("brave-browser"),
		exepath("microsoft-edge"),
	}

	if uv.os_uname().sysname == "Darwin" then
		vim.list_extend(candidates, {
			"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
			"/Applications/Chromium.app/Contents/MacOS/Chromium",
			"/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
			"/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
		})
	end

	for _, candidate in ipairs(candidates) do
		if is_file(candidate) then
			return candidate
		end
	end

	return nil
end

local function json_encode(value)
	if vim.json and vim.json.encode then
		return vim.json.encode(value)
	end
	return vim.fn.json_encode(value)
end

function M.puppeteer_config_path(browser_path)
	local dir = vim.fn.stdpath("cache") .. "/mermaid"
	vim.fn.mkdir(dir, "p")
	local path = dir .. "/puppeteer-config.json"
	local config = {
		executablePath = browser_path,
		args = {},
	}

	local uv = vim.uv or vim.loop
	if uv.os_uname().sysname == "Linux" then
		config.args = { "--no-sandbox", "--disable-dev-shm-usage" }
	end

	vim.fn.writefile({ json_encode(config) }, path)
	return path
end

local function viewer_html(svg_path, svg)
	local title = html_escape(vim.fn.fnamemodify(svg_path, ":t"))

	return table.concat({
		"<!doctype html>",
		'<html lang="en">',
		"<head>",
		'<meta charset="utf-8">',
		'<meta name="viewport" content="width=device-width, initial-scale=1">',
		"<title>" .. title .. "</title>",
		"<style>",
		'html, body { height: 100%; margin: 0; overflow: hidden; background: #111318; color: #f4f4f5; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }',
		"#viewport { width: 100vw; height: 100vh; overflow: hidden; cursor: grab; touch-action: none; user-select: none; -webkit-user-select: none; }",
		"#viewport.dragging { cursor: grabbing; }",
		"#canvas { transform-origin: 0 0; will-change: transform; }",
		"#canvas, #canvas * { user-select: none; -webkit-user-select: none; }",
		"#canvas svg { display: block; max-width: none !important; background: white; }",
		"#toolbar { position: fixed; top: 12px; left: 12px; z-index: 1; display: flex; align-items: center; gap: 8px; padding: 8px; border-radius: 8px; background: rgba(17, 19, 24, 0.84); box-shadow: 0 8px 28px rgba(0, 0, 0, 0.28); backdrop-filter: blur(10px); }",
		"button { border: 1px solid rgba(255, 255, 255, 0.22); border-radius: 6px; background: #272b33; color: #f4f4f5; padding: 5px 9px; font: inherit; cursor: pointer; }",
		"button:hover { background: #343946; }",
		"#hint { color: #c6cbd4; font-size: 12px; }",
		"</style>",
		"</head>",
		"<body>",
		'<div id="toolbar">',
		'<button id="fit" type="button">Fit</button>',
		'<button id="actual" type="button">1:1</button>',
		'<span id="hint">wheel zoom, drag pan, double-click fit</span>',
		"</div>",
		'<div id="viewport"><div id="canvas">',
		svg,
		"</div></div>",
		"<script>",
		"(function () {",
		'  var viewport = document.getElementById("viewport");',
		'  var canvas = document.getElementById("canvas");',
		"  var svg = canvas.querySelector('svg');",
		"  var state = { x: 0, y: 0, scale: 1, dragging: false, lastX: 0, lastY: 0 };",
		"  function clamp(value, min, max) { return Math.min(max, Math.max(min, value)); }",
		"  function sizeSvg() {",
		"    var viewBox = svg && svg.viewBox && svg.viewBox.baseVal;",
		"    var width = viewBox && viewBox.width ? viewBox.width : 1200;",
		"    var height = viewBox && viewBox.height ? viewBox.height : 800;",
		'    svg.removeAttribute("width");',
		'    svg.removeAttribute("height");',
		'    svg.style.width = width + "px";',
		'    svg.style.height = height + "px";',
		'    svg.style.maxWidth = "none";',
		"    return { width: width, height: height };",
		"  }",
		"  function apply() { canvas.style.transform = 'translate(' + state.x + 'px, ' + state.y + 'px) scale(' + state.scale + ')'; }",
		"  function fit() {",
		"    var diagram = sizeSvg();",
		"    var bounds = viewport.getBoundingClientRect();",
		"    state.scale = clamp(Math.min(bounds.width / diagram.width, bounds.height / diagram.height) * 0.94, 0.02, 8);",
		"    state.x = (bounds.width - diagram.width * state.scale) / 2;",
		"    state.y = (bounds.height - diagram.height * state.scale) / 2;",
		"    apply();",
		"  }",
		"  function actualSize() {",
		"    sizeSvg();",
		"    state.scale = 1;",
		"    state.x = 24;",
		"    state.y = 64;",
		"    apply();",
		"  }",
		"  viewport.addEventListener('wheel', function (event) {",
		"    event.preventDefault();",
		"    var bounds = viewport.getBoundingClientRect();",
		"    var mouseX = event.clientX - bounds.left;",
		"    var mouseY = event.clientY - bounds.top;",
		"    var beforeX = (mouseX - state.x) / state.scale;",
		"    var beforeY = (mouseY - state.y) / state.scale;",
		"    var factor = Math.exp(-event.deltaY * 0.001);",
		"    state.scale = clamp(state.scale * factor, 0.02, 24);",
		"    state.x = mouseX - beforeX * state.scale;",
		"    state.y = mouseY - beforeY * state.scale;",
		"    apply();",
		"  }, { passive: false });",
		"  viewport.addEventListener('pointerdown', function (event) {",
		"    event.preventDefault();",
		"    state.dragging = true;",
		"    state.lastX = event.clientX;",
		"    state.lastY = event.clientY;",
		"    viewport.classList.add('dragging');",
		"    viewport.setPointerCapture(event.pointerId);",
		"  });",
		"  viewport.addEventListener('pointermove', function (event) {",
		"    if (!state.dragging) return;",
		"    state.x += event.clientX - state.lastX;",
		"    state.y += event.clientY - state.lastY;",
		"    state.lastX = event.clientX;",
		"    state.lastY = event.clientY;",
		"    apply();",
		"  });",
		"  function stopDrag(event) {",
		"    state.dragging = false;",
		"    viewport.classList.remove('dragging');",
		"    if (event && viewport.hasPointerCapture(event.pointerId)) viewport.releasePointerCapture(event.pointerId);",
		"  }",
		"  viewport.addEventListener('pointerup', stopDrag);",
		"  viewport.addEventListener('pointercancel', stopDrag);",
		"  viewport.addEventListener('dblclick', fit);",
		"  window.addEventListener('resize', fit);",
		"  document.getElementById('fit').addEventListener('click', fit);",
		"  document.getElementById('actual').addEventListener('click', actualSize);",
		"  fit();",
		"}());",
		"</script>",
		"</body>",
		"</html>",
	}, "\n")
end

function M.write_svg_viewer(svg_path)
	local lines = vim.fn.readfile(svg_path)
	local svg = table.concat(lines, "\n")
	local viewer_path = M.viewer_path_for(svg_path)
	vim.fn.writefile(vim.split(viewer_html(svg_path, svg), "\n", { plain = true }), viewer_path)
	return viewer_path
end

local function open_file(path)
	if not is_file(path) then
		notify("Cannot open missing file: " .. path, vim.log.levels.ERROR)
		return
	end

	if vim.ui and vim.ui.open then
		local ok, result, err = pcall(vim.ui.open, path)
		if ok and result then
			return
		end
		notify("vim.ui.open failed: " .. tostring(ok and err or result), vim.log.levels.WARN)
	end

	local command
	local uv = vim.uv or vim.loop
	if uv.os_uname().sysname == "Darwin" then
		command = { "open", path }
	elseif vim.fn.has("win32") == 1 then
		command = { "cmd.exe", "/c", "start", "", path }
	else
		command = { "xdg-open", path }
	end

	if vim.fn.executable(command[1]) ~= 1 then
		notify("No file opener found for " .. path, vim.log.levels.ERROR)
		return
	end

	vim.fn.jobstart(command, { detach = true })
end

local function render_file(input_path, output_path)
	if vim.fn.executable("mmdc") ~= 1 then
		notify("mmdc is not available on PATH; rebuild the Nix profile with mermaid-cli.", vim.log.levels.ERROR)
		return
	end

	local browser_path = M.find_browser()
	if browser_path == nil then
		notify(
			"Chrome/Chromium was not found. Install Chromium or set PUPPETEER_EXECUTABLE_PATH.",
			vim.log.levels.ERROR
		)
		return
	end

	local puppeteer_config = M.puppeteer_config_path(browser_path)
	local rendered_after = os.time()

	notify("Rendering " .. vim.fn.fnamemodify(input_path, ":t") .. " to SVG...")
	vim.system(
		{ "mmdc", "-i", input_path, "-o", output_path, "--puppeteerConfigFile", puppeteer_config },
		{ text = true },
		function(result)
			vim.schedule(function()
				if result.code ~= 0 then
					local detail = result.stderr or result.stdout or "unknown error"
					notify("mmdc failed: " .. vim.trim(detail), vim.log.levels.ERROR)
					return
				end

				local outputs = M.rendered_outputs_for(output_path, rendered_after)
				if #outputs == 0 then
					local detail = vim.trim(result.stderr or result.stdout or "")
					if detail ~= "" then
						detail = " mmdc output: " .. detail
					end
					notify(
						"mmdc finished but no SVG was created for " .. output_path .. "." .. detail,
						vim.log.levels.ERROR
					)
					return
				end

				if #outputs == 1 then
					notify("Rendered " .. outputs[1])
				else
					notify("Rendered " .. #outputs .. " SVGs; opening " .. outputs[1])
				end
				local viewer_path = M.write_svg_viewer(outputs[1])
				open_file(viewer_path)
			end)
		end
	)
end

function M.render_current_buffer()
	local input_path = vim.api.nvim_buf_get_name(0)
	if input_path == "" then
		notify("Current buffer does not have a file path.", vim.log.levels.ERROR)
		return
	end

	if vim.bo.modified then
		local ok, err = pcall(vim.cmd.write)
		if not ok then
			notify("Could not write current buffer: " .. tostring(err), vim.log.levels.ERROR)
			return
		end
	end

	render_file(input_path, M.output_path_for(input_path))
end

function M.setup()
	vim.api.nvim_create_user_command("MermaidRenderOpen", M.render_current_buffer, {
		desc = "Render the current Mermaid file to a pan/zoom SVG viewer and open it",
	})
end

return M
