local lspconfig = require('lspconfig')

-- utils.print(lspconfig.util.root_pattern('.git', vim.fn.getcwd()))

return {
    cmd = { 'sql-language-server', 'up', '--method', 'stdio'},
    filetypes = { 'sql', 'mysql', 'pgsql' },
    -- root_dir = lspconfig.util.root_pattern('.git', vim.fn.getcwd()),
    root_dir = lspconfig.util.root_pattern '.sqllsrc.json',
}
