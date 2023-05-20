local utils = require("user.utils")
local conns = utils.get_db_connections()
local sqls_conns = {}
for _, conn in ipairs(conns) do
	local conn_string = utils.connection_to_golang_string(conn)
	if conn_string ~= nil then
		table.insert(sqls_conns, {
			driver = conn["adapter"],
			dataSourceName = conn_string,
		})
	end
end
return {
	settings = {
		sqls = {
			connections = sqls_conns,
		},
	},
}
