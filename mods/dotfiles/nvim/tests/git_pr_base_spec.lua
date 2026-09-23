local function run(cmd, cwd)
	local result = vim.system(cmd, { cwd = cwd, text = true }):wait()
	assert(result.code == 0, string.format("command failed (%s):\n%s", table.concat(cmd, " "), result.stderr or ""))
	return vim.trim(result.stdout or "")
end

local function git(cwd, ...)
	local cmd = { "git" }
	vim.list_extend(cmd, { ... })
	return run(cmd, cwd)
end

local original_cwd = vim.fn.getcwd()
local original_path = vim.env.PATH
local temp = vim.fn.tempname()
local repo = temp .. "/repo"
local remote = temp .. "/origin.git"
local other_clone = temp .. "/other"
local bin = temp .. "/bin"

vim.fn.mkdir(repo, "p")
vim.fn.mkdir(bin, "p")
run({ "git", "init", "--bare", remote }, temp)
git(repo, "init", "-b", "main")
git(repo, "config", "user.email", "test@example.com")
git(repo, "config", "user.name", "Test")
git(repo, "remote", "add", "origin", remote)

vim.fn.writefile({ "main" }, repo .. "/main.txt")
git(repo, "add", "main.txt")
git(repo, "commit", "-m", "main")
git(repo, "push", "-u", "origin", "main")

git(repo, "switch", "-c", "parent")
vim.fn.writefile({ "parent one" }, repo .. "/parent-one.txt")
git(repo, "add", "parent-one.txt")
git(repo, "commit", "-m", "parent one")
local original_parent_tip = git(repo, "rev-parse", "HEAD")
git(repo, "push", "-u", "origin", "parent")

git(repo, "switch", "-c", "child")
vim.fn.writefile({ "child" }, repo .. "/child.txt")
git(repo, "add", "child.txt")
git(repo, "commit", "-m", "child")

git(repo, "switch", "parent")
vim.fn.writefile({ "parent two" }, repo .. "/parent-two.txt")
git(repo, "add", "parent-two.txt")
git(repo, "commit", "-m", "parent two")
local advanced_parent_tip = git(repo, "rev-parse", "HEAD")
git(repo, "push", "origin", "parent")
git(repo, "switch", "child")

local gh_path = bin .. "/gh"
local function fake_gh(lines)
	vim.fn.writefile(lines, gh_path)
	vim.fn.setfperm(gh_path, "rwxr-xr-x")
end

fake_gh({ "#!/bin/sh", "exit 1" })
vim.env.PATH = bin .. ":" .. original_path
vim.uv.chdir(repo)

local pr_base = require("user.utils.git_pr_base")

-- A parent that advances after the child forks must still resolve to their
-- original merge base. The old graph-distance heuristic fell back to main.
git(repo, "config", "--local", "branch.child.prBase", "parent")
local resolved, err = pr_base.resolve()
assert(resolved, err and err.message or "expected configured parent to resolve")
assert(resolved.parent == "parent", "expected configured parent")
assert(resolved.source == "git-config", "expected git config source")
assert(resolved.commit == original_parent_tip, "expected GitHub-style merge base")
assert(resolved.parent_ref == "refs/remotes/origin/parent", "expected fetched origin parent")

-- An existing GitHub PR is authoritative over saved local configuration.
git(repo, "config", "--local", "branch.child.prBase", "main")
fake_gh({ "#!/bin/sh", "printf 'parent\\n'" })
resolved, err = pr_base.resolve()
assert(resolved, err and err.message or "expected GitHub parent to resolve")
assert(resolved.parent == "parent", "expected GitHub PR parent")
assert(resolved.source == "github", "expected GitHub source")
assert(resolved.commit == original_parent_tip, "expected merge base against GitHub parent")

-- Without authoritative metadata, resolution must fail closed so the caller
-- can prompt instead of guessing from an ambiguous commit graph.
fake_gh({ "#!/bin/sh", "exit 1" })
git(repo, "config", "--local", "--unset", "branch.child.prBase")
resolved, err = pr_base.resolve()
assert(resolved == nil, "expected missing parent to require selection")
assert(err and err.kind == "parent_required", "expected parent_required error")

-- Remembering a picker selection stores normalized, branch-local Git metadata.
resolved, err = pr_base.remember_and_resolve("origin/parent")
assert(resolved, err and err.message or "expected remembered parent to resolve")
assert(git(repo, "config", "--get", "branch.child.prBase") == "parent", "expected normalized saved parent")
assert(resolved.commit == original_parent_tip, "expected remembered parent merge base")

-- Recompute the merge base rather than trusting a stored historical fork point.
git(repo, "merge", "--no-edit", "parent")
resolved, err = pr_base.resolve()
assert(resolved, err and err.message or "expected merged parent to resolve")
assert(resolved.commit == advanced_parent_tip, "expected current merge base after merging parent")

-- A force-pushed GitHub parent must replace the stale remote-tracking ref.
-- Otherwise the comparison silently keeps using the parent's old history.
run({ "git", "clone", remote, other_clone }, temp)
git(other_clone, "config", "user.email", "test@example.com")
git(other_clone, "config", "user.name", "Test")
git(other_clone, "switch", "parent")
git(other_clone, "reset", "--hard", "origin/main")
vim.fn.writefile({ "rewritten parent" }, other_clone .. "/rewritten-parent.txt")
git(other_clone, "add", "rewritten-parent.txt")
git(other_clone, "commit", "-m", "rewritten parent")
git(other_clone, "push", "--force", "origin", "parent")
local main_tip = git(repo, "rev-parse", "main")
resolved, err = pr_base.resolve()
assert(resolved, err and err.message or "expected force-pushed parent to resolve")
assert(resolved.commit == main_tip, "expected merge base against refreshed force-pushed parent")

-- If origin cannot be refreshed, a stale remote-tracking ref is not reliable
-- enough to claim that this is the GitHub comparison base.
git(repo, "remote", "set-url", "origin", temp .. "/missing.git")
resolved, err = pr_base.resolve()
assert(resolved == nil, "expected an origin refresh failure to fail closed")
assert(err and err.kind == "fetch_failed", "expected fetch_failed error")

vim.uv.chdir(original_cwd)
vim.env.PATH = original_path
vim.fn.delete(temp, "rf")

print("git_pr_base_spec: ok")
