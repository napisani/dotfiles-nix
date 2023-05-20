local status_ok, dbee = pcall(require, "dbee")
if not status_ok then
	vim.notify("dbee not found ")
	return
end
local utils = require("user.utils")
local conns = utils.get_db_connections()
local dbee_conns = {}
for _, conn in ipairs(conns) do
	local conn_string = utils.connection_to_golang_string(conn)
	if conn_string ~= nil then
		table.insert(dbee_conns, {
			name = conn["database"] .. "@" .. conn["host"],
			type = conn["adapter"],
			url = conn_string,
		})
	end
end
dbee.setup({
	lazy = true,
	connections = dbee_conns,
	drawer = {
		mappings = {
			-- manually refresh drawer
			refresh = { key = "R", mode = "n" },
			-- actions perform different stuff depending on the node:
			-- action_1 opens a scratchpad or executes a helper
			action_1 = { key = "<CR>", mode = "n" },
			-- action_2 renames a scratchpad or sets the connection as active manually
			action_2 = { key = "r", mode = "n" },
			-- action_3 deletes a scratchpad
			action_3 = { key = "d", mode = "n" },
			-- these are self-explanatory:
			collapse = { key = "zc", mode = "n" },
			expand = { key = "zo", mode = "n" },
			toggle = { key = "o", mode = "n" },
		},
  result = {
    mappings = {
      -- next/previous page
      page_next = { key = "N", mode = "" },
      page_prev = { key = "P", mode = "" },
    },
  },
	},
})
