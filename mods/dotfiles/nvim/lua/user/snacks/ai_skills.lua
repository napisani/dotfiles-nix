---@module "user.snacks.ai_skills"

local M = {}

local uv = vim.uv or vim.loop

local cache = {
	key = nil,
	skills = nil,
	cached_at = 0,
}

local function joinpath(...)
	local parts = { ... }
	if vim.fs and vim.fs.joinpath then
		return vim.fs.joinpath(unpack(parts))
	end
	return table.concat(parts, "/"):gsub("/+", "/")
end

local function trim(value)
	return vim.trim(value or "")
end

local function unquote(value)
	value = trim(value)
	local first = value:sub(1, 1)
	local last = value:sub(-1)
	if #value >= 2 and ((first == '"' and last == '"') or (first == "'" and last == "'")) then
		return value:sub(2, -2)
	end
	return value
end

function M.current_repo_root()
	local cwd = uv.cwd()
	if not cwd or cwd == "" then
		return nil
	end

	local marker = vim.fs.find({ ".git", "flake.nix" }, {
		path = cwd,
		upward = true,
	})[1]
	if not marker then
		return cwd
	end

	return vim.fs.dirname(marker)
end

function M.default_skill_dirs()
	local repo_root = M.current_repo_root()
	local dirs = {}
	if repo_root then
		table.insert(dirs, joinpath(repo_root, ".agents", "skills"))
	end
	table.insert(dirs, vim.fn.expand("~/.agents/skills"))
	return dirs
end

function M.is_prompt_builder(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end
	local ok, value = pcall(vim.api.nvim_buf_get_var, bufnr, "prompt_builder")
	return ok and value == true
end

local function parse_frontmatter(lines)
	if lines[1] ~= "---" then
		return {}
	end

	local metadata = {}
	for i = 2, #lines do
		local line = lines[i]
		if line == "---" then
			break
		end

		local key, value = line:match("^([%w_-]+):%s*(.-)%s*$")
		if key and value then
			metadata[key] = unquote(value)
		end
	end

	return metadata
end

local function read_skill(skill_dir, fallback_name)
	local skill_md = joinpath(skill_dir, "SKILL.md")
	if vim.fn.filereadable(skill_md) ~= 1 then
		return nil
	end

	local ok, lines = pcall(vim.fn.readfile, skill_md)
	if not ok then
		return nil
	end

	local metadata = parse_frontmatter(lines)
	local name = trim(metadata.name)
	if name == "" then
		name = fallback_name
	end

	if not name or name == "" then
		return nil
	end

	return {
		name = name,
		description = trim(metadata.description),
		path = skill_md,
	}
end

local function scan_dir(root)
	if not root or root == "" or vim.fn.isdirectory(root) ~= 1 then
		return {}
	end

	local skills = {}
	for name, entry_type in vim.fs.dir(root) do
		if entry_type == "directory" or entry_type == "link" then
			local skill = read_skill(joinpath(root, name), name)
			if skill then
				table.insert(skills, skill)
			end
		end
	end
	return skills
end

function M.list(opts)
	opts = opts or {}
	local skill_dirs = opts.skill_dirs or M.default_skill_dirs()
	local skill_dirs_key = table.concat(skill_dirs, "\n")
	local now = uv.now()
	local cache_ttl_ms = opts.cache_ttl_ms or 5000

	if cache.skills and cache.key == skill_dirs_key and now - cache.cached_at < cache_ttl_ms then
		return cache.skills
	end

	local by_name = {}
	for _, dir in ipairs(skill_dirs) do
		for _, skill in ipairs(scan_dir(dir)) do
			if not by_name[skill.name] then
				by_name[skill.name] = skill
			end
		end
	end

	local skills = vim.tbl_values(by_name)
	table.sort(skills, function(left, right)
		return left.name < right.name
	end)

	cache.key = skill_dirs_key
	cache.skills = skills
	cache.cached_at = now
	return skills
end

function M.skill_invocation(skill)
	local name = type(skill) == "table" and skill.name or skill
	name = trim(name)
	if name == "" then
		return ""
	end
	return "/" .. name
end

local function format_picker_item(item)
	if not item then
		return ""
	end
	if item.description and item.description ~= "" then
		return string.format("%s  %s", item.label or M.skill_invocation(item), item.description)
	end
	return item.label or M.skill_invocation(item)
end

local function picker_items(skills)
	local items = {}
	for _, skill in ipairs(skills) do
		local invocation = M.skill_invocation(skill)
		table.insert(items, {
			name = skill.name,
			description = skill.description,
			path = skill.path,
			file = skill.path,
			label = invocation,
			text = invocation .. " " .. skill.name .. " " .. (skill.description or ""),
		})
	end
	return items
end

function M.pick_to_prompt_builder(opts)
	opts = opts or {}
	local items = picker_items(M.list(opts))
	if #items == 0 then
		vim.notify("No AI skills found", vim.log.levels.WARN)
		return
	end

	local prompt = opts.prompt or "Skills -> PromptBuilder"
	local function on_choice(item)
		if not item then
			return
		end
		local invocation = M.skill_invocation(item)
		if invocation ~= "" then
			require("user.prompt_builder").append_text(invocation)
		end
	end

	local ok, Snacks = pcall(require, "snacks")
	if ok and Snacks.picker and Snacks.picker.pick then
		Snacks.picker.pick({
			items = items,
			prompt = prompt,
			format_item = format_picker_item,
			confirm = function(picker, item)
				on_choice(item)
				if picker and picker.close then
					picker:close()
				end
			end,
		})
		return
	end

	vim.ui.select(items, {
		prompt = prompt,
		format_item = format_picker_item,
	}, on_choice)
end

return M
