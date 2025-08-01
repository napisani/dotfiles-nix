local codecompanion = require("codecompanion")
local config = require("codecompanion.config")
local util = require("codecompanion.utils")
local path = require("plenary.path")
local file_utils = require("user._file_utils")

local M = {}
function M.add_file_to_chat(picker_fn, picker_opts)
	picker_opts = picker_opts or {}
	local fmt = string.format

	-- Get the current chat if available
	local chat = codecompanion.last_chat()
	if not chat then
		vim.notify("No active CodeCompanion chat", vim.log.levels.ERROR)
		return
	end

	local function coerce_and_validate_selection(selection)
		if type(selection) ~= "table" then
			-- raise an error if the selection is not a table
			vim.notify("Invalid selection type: " .. type(selection), vim.log.levels.ERROR)
		end
		if not selection.file or selection.file == "" then
			-- raise an error if the file is not specified
			vim.notify("No file selected", vim.log.levels.ERROR)
			return
		end

		selection.cwd = selection.cwd or file_utils.get_root_dir()
		-- if the path starts with a slash, it is an absolute path
		if selection.file:sub(1, 1) == "/" then
			selection.file_path = selection.file
		else
			selection.file_path = vim.fs.joinpath(selection.cwd, selection.file)
		end

		selection.relative_path = vim.fn.fnamemodify(selection.file_path, ":.")

		return selection
	end

	local function add_file_name_ref_to_chat(selection)
		-- Insert the name of the file into the chat buffer at the current cursor position
		selection = coerce_and_validate_selection(selection)
		local bufnr = chat.bufnr

		local relative_path = selection.relative_path

		-- insert the file name at the current cursor position
		vim.api.nvim_buf_set_lines(
			bufnr,
			vim.api.nvim_win_get_cursor(0)[1],
			vim.api.nvim_win_get_cursor(0)[1],
			false,
			{ "`" .. relative_path .. "`" }
		)
	end

	local function add_file_attachment_to_chat(selection)
		selection = coerce_and_validate_selection(selection)
		local file_path = selection.file_path
		local relative_path = selection.relative_path

		-- Read file content
		local ok, content = pcall(function()
			return path.new(file_path):read()
		end)

		if not ok or content == "" then
			vim.notify("Could not read the file: " .. file_path, vim.log.levels.WARN)
			return
		end

		-- Get filetype for syntax highlighting
		local ft = vim.filetype.match({ filename = file_path })
		local id = "<file>" .. relative_path .. "</file>"

		-- Format the content with Markdown
		local description = fmt(
			[[<attachment filepath="%s">Here is the content from the file:
      
```%s
%s
```
</attachment>]],
			relative_path,
			ft,
			content
		)

		-- Add message to chat
		chat:add_message({
			role = config.constants.USER_ROLE,
			content = description or "",
		}, { reference = id, visible = false })

		-- Add file reference
		local source = "whichkey.file_command"
		chat:add_context({ content = file_path, role = "user" }, source, id)

		-- Notify user
		util.notify(fmt("Added the `%s` file to the chat", vim.fn.fnamemodify(relative_path, ":t")))
	end

	-- Launch snacks.nvim picker
	local all_opts = vim.tbl_extend("force", picker_opts, {
		multi_select = true,
		confirm = function(picker)
			-- Get the selected items
			local selection = picker:selected({ fallback = true })
			picker:close()
			if type(selection) == "table" and #selection > 0 then
				-- Multiple files selected
				for _, selected_item in ipairs(selection) do
					add_file_attachment_to_chat(selected_item)
				end

				for _, selected_item in ipairs(selection) do
					add_file_name_ref_to_chat(selected_item)
				end
			else
				-- Single file selected
				add_file_attachment_to_chat(selection)
				add_file_name_ref_to_chat(selection)
			end
		end,
	})

	picker_fn(all_opts)
end

return M
