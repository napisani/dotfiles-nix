local status_ok, gh_search = pcall(require, "nvim-github-codesearch")
if not status_ok then
	vim.notify("nvim-github-codesearch not found ")
	return
end
gh_search.setup({
  github_auth_token = os.getenv("GIT_NPM_AUTH_TOKEN"),
  use_telescope = true
})


