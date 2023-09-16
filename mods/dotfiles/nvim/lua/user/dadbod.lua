local utils = require("user.utils")
--[=====[ 
// dbs.json
{
  "connections": {
    "name": "URL"
  }
}
--]=====]

local function get_project_db_urls()
	local dbs_file = utils.get_root_dir() .. "/dbs.json"
	local json_file = utils.read_json_file(dbs_file)
	if json_file == nil then
		return {}
	end
	local conns = {}
	if json_file["connections"] ~= nil then
		conns = json_file["connections"]
	end
	return conns
end

vim.g.dbs = get_project_db_urls()
vim.g.db_ui_use_nerd_fonts = 1

-- enable auto complete for table names and other db assets
vim.api.nvim_create_autocmd("FileType", {
  desc = "dadbod completion",
  group = vim.api.nvim_create_augroup("dadbod_cmp", { clear = true }),
  pattern = { "sql", "mysql", "plsql" },
  callback = function()
    require("cmp").setup.buffer({ sources = { { name = "vim-dadbod-completion" } } })
  end,
})
