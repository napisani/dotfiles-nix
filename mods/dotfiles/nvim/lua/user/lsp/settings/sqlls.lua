local lspconfig = require('lspconfig')
-- local utils = require('user.utils')

-- utils.print(lspconfig.util.root_pattern('.git', vim.fn.getcwd()))

return {
    cmd = { 'sql-language-server', 'up', '--method', 'stdio'},
    filetypes = { 'sql', 'mysql', 'pgsql' },
    -- root_dir = lspconfig.util.root_pattern('.git', vim.fn.getcwd()),
    root_dir = lspconfig.util.root_pattern '.sqllsrc.json',
    -- root_dir = utils.get_root_dir(),
}
