local utils = require("user.utils")
local action_set = require("telescope.actions.set")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local putils = require("telescope.previewers.utils")
local common = require("user.telescope.common")
local actions = require("telescope.actions")

local plenary_ok, PlenaryJob = pcall(require, "plenary.job")
if not plenary_ok then
	vim.notify("plenary not found")
	return
end

local tmux_pane_id = nil

local function get_tmux_pane_id()
	if tmux_pane_id ~= nil then
		return tmux_pane_id
	end
	vim.fn.system("tmux display-panes")
	tmux_pane_id = vim.fn.input("Enter Pane ID: ")
	return tmux_pane_id
end

local function parse_cmd_parameter(text)
	local pattern = "<([^=]+)=([^>]*)>"
	local name, value = string.match(text, pattern)
	if name and value then
		return {
			name = name,
			value = value,
		}
	end
	return nil
end

local function do_command_replacements(cmd)
	-- parse format <name=defaultValue>
	local result = cmd
	for placeholder in cmd:gmatch("<[^>]+>") do
		local parsed = parse_cmd_parameter(placeholder)
		if parsed then
			-- For now we just return the default value
			local val = vim.fn.input(parsed.name .. " (" .. parsed.value .. "): ")
			if val == "" then
				val = parsed.value
			end
			result = result:gsub(vim.pesc(placeholder), val)
		end
	end
	return result
end

local function run_cmd_in_tmux(cmd)
	local pane_id = get_tmux_pane_id()
	cmd = do_command_replacements(cmd)
	local job = PlenaryJob:new({
		command = "tmux",
		args = {
			"send-keys",
			"-t",
			pane_id,
			cmd,
			"Enter",
		},
	})
	job:start()
end

M.project_commands = function(opts)
	opts = opts or {}
	opts.cwd = utils.get_root_dir()

	local cmd = {
		"animal-rescue",
		"--config",
		vim.env.HOME .. "/.config/pet/config.toml",
		"--snippets",
		"--search-path",
		opts.cwd,
	}

	local pet_data_raw = vim.fn.system(cmd)
	local json_snippets = vim.fn.json_decode(pet_data_raw)

	local to_preview = function(snippet)
		local content = {}
		table.insert(content, snippet.command)
		table.insert(content, "")
		table.insert(content, "# " .. snippet.description)
		return content
	end
	local entries = {}
	for _, snippet in ipairs(json_snippets["snippets"]) do
		local content = to_preview(snippet)
		table.insert(entries, {
			value = snippet.command,
			display = snippet.description,
			ordinal = snippet.description,
			content = content,
		})
	end
	opts.results = entries
	local project_commands = utils.get_project_config().commands
	for _, command in ipairs(project_commands) do
		local content = to_preview(command)
		table.insert(entries, {
			value = command.command,
			display = command.description,
			ordinal = command.description,
			content = content,
		})
	end

	local custom_previewer = previewers.new_buffer_previewer({
		title = "Command Preview",
		get_buffer_by_name = function(_, entry)
			return entry.value
		end,

		define_preview = function(self, entry, status)
			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, entry.content)
			putils.regex_highlighter(self.state.bufnr, "bash")
		end,
	})

	return pickers
		.new(
			opts,
			utils.table_merge(common.picker_layout, {
				prompt_title = "Project Commands",
				previewer = custom_previewer,
				sorter = conf.file_sorter(opts),
				finder = finders.new_table({
					results = entries,
					entry_maker = function(entry)
						return entry
					end,
				}),

				attach_mappings = function(prompt_bufnr)
					action_set.select:replace(function()
						local selection = action_state.get_selected_entry()
						run_cmd_in_tmux(selection.value)
						actions.close(prompt_bufnr)
					end)
					return true
				end,
			})
		)
		:find()
end
return M
