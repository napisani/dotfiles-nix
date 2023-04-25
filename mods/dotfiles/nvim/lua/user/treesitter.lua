local status_ok, configs = pcall(require, "nvim-treesitter.configs")
if not status_ok then
  vim.notify('nvim-treesitter.configs not found')
  return
end

-- local status_ok_p, parsers = pcall(require, "nvim-treesitter.parsers")
-- if not status_ok_p then
--   vim.notify('nvim-treesitter.parsers not found')
-- 	return
-- end

configs.setup({
  ensure_installed = "all", -- one of "all" or a list of languages
  ignore_install = { "phpdoc", "tree-sitter-phpdoc" }, -- List of parsers to ignore installing
  highlight = {
    enable = true, -- false will disable the whole extension
    disable = { "css" }, -- list of language that will be disabled
  },
  autopairs = {
    enable = true,
  },
  indent = { enable = true, disable = {
    "python",
    "css"
  } },
})
-- local parser_config = parsers.get_parser_configs()
-- parser_config.gotmpl = {
--   install_info = {
--     url = "https://github.com/ngalaiko/tree-sitter-go-template",
--     files = {"src/parser.c"}
--   },
--   filetype = "gotmpl",
--   used_by = {"gohtmltmpl", "gotexttmpl", "gotmpl", "yaml"}
-- }
