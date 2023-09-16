vim.g.dbs = {
  localstudymax = 'sqlserver://sa:Studymax%40123@localhost:1433?database=studymaxuatv2',
  stagingstudymax =
  'sqlserver://dbadmin:Studymax%40123@studymaxdev-server.database.windows.net?database=studymaxstaging&ApplicationIntent=ReadWrite'
}

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
