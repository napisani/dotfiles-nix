local file_utils = require("user.utils.file_utils")

local M = {}

local function failure(kind, message)
	return nil, { kind = kind, message = message }
end

local function command(root, args, timeout)
	return vim.system(args, { cwd = root, text = true }):wait(timeout or 5000)
end

local function output(result)
	if result.code ~= 0 then
		return nil
	end
	local value = vim.trim(result.stdout or "")
	return value ~= "" and value or nil
end

local function git(root, args, timeout)
	local cmd = { "git" }
	vim.list_extend(cmd, args)
	return command(root, cmd, timeout)
end

local function current_branch(root)
	return output(git(root, { "symbolic-ref", "--short", "-q", "HEAD" }))
end

local function normalize_parent(parent)
	parent = vim.trim(parent or "")
	parent = parent:gsub("^refs/remotes/origin/", "")
	parent = parent:gsub("^refs/heads/", "")
	parent = parent:gsub("^origin/", "")
	return parent
end

local function ref_exists(root, ref)
	return output(git(root, { "rev-parse", "--verify", "--quiet", ref .. "^{commit}" })) ~= nil
end

local function github_parent(root, branch)
	local result = command(root, { "gh", "pr", "view", branch, "--json", "baseRefName", "--jq", ".baseRefName" }, 5000)
	local parent = output(result)
	if parent == "null" then
		return nil
	end
	return parent
end

local function configured_parent(root, branch)
	return output(git(root, { "config", "--local", "--get", "branch." .. branch .. ".prBase" }))
end

local function resolve_parent_ref(root, parent)
	local remote_ref = "refs/remotes/origin/" .. parent
	local has_origin = output(git(root, { "remote", "get-url", "origin" })) ~= nil

	if has_origin then
		local fetch = git(root, { "fetch", "--quiet", "origin", "+refs/heads/" .. parent .. ":" .. remote_ref }, 10000)
		if fetch.code ~= 0 then
			return nil, "could not refresh origin/" .. parent
		end
		if ref_exists(root, remote_ref) then
			return remote_ref
		end
		return nil, "origin/" .. parent .. " did not resolve after fetching"
	end

	local local_ref = "refs/heads/" .. parent
	if ref_exists(root, local_ref) then
		return local_ref
	end
	if ref_exists(root, parent) then
		return parent
	end
	return nil
end

function M.resolve_for_parent(parent, source)
	local root = file_utils.get_root_dir()
	local branch = current_branch(root)
	if not branch then
		return failure("detached_head", "cannot determine a PR parent while HEAD is detached")
	end

	parent = normalize_parent(parent)
	if parent == "" then
		return failure("parent_required", "select the branch this PR should target")
	end
	if parent == branch then
		return failure("invalid_parent", "the current branch cannot be its own PR parent")
	end

	local parent_ref, fetch_error = resolve_parent_ref(root, parent)
	if fetch_error then
		return failure("fetch_failed", fetch_error)
	end
	if not parent_ref then
		return failure("missing_parent", "could not resolve parent branch " .. parent)
	end

	local merge_base = output(git(root, { "merge-base", "HEAD", parent_ref }))
	if not merge_base then
		return failure("no_merge_base", "HEAD and " .. parent_ref .. " have no merge base")
	end

	return {
		commit = merge_base,
		parent = parent,
		parent_ref = parent_ref,
		source = source or "selected",
	}
end

function M.resolve()
	local root = file_utils.get_root_dir()
	local branch = current_branch(root)
	if not branch then
		return failure("detached_head", "cannot determine a PR parent while HEAD is detached")
	end

	local parent = github_parent(root, branch)
	if parent then
		return M.resolve_for_parent(parent, "github")
	end

	parent = configured_parent(root, branch)
	if parent then
		return M.resolve_for_parent(parent, "git-config")
	end

	return failure("parent_required", "no open GitHub PR or saved PR parent for " .. branch)
end

function M.remember_and_resolve(parent)
	local root = file_utils.get_root_dir()
	local branch = current_branch(root)
	if not branch then
		return failure("detached_head", "cannot save a PR parent while HEAD is detached")
	end

	parent = normalize_parent(parent)
	local resolved, err = M.resolve_for_parent(parent, "picker")
	if not resolved then
		return nil, err
	end

	local saved = git(root, { "config", "--local", "branch." .. branch .. ".prBase", parent })
	if saved.code ~= 0 then
		return failure("config_failed", "could not save PR parent for " .. branch)
	end
	return resolved
end

return M
