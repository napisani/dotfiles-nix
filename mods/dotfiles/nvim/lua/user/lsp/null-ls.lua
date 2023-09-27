local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
  vim.notify("null-ls not found")
  return
end

-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/formatting
local formatting = null_ls.builtins.formatting
-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics
local diagnostics = null_ls.builtins.diagnostics

local utils = require("user.utils")
-- npm install -g cspell
local cspell = {
  name = "cspell",
  method = null_ls.methods.DIAGNOSTICS,
  -- filetypes = { "python" },
  filetypes = { "markdown", "text", "latex", "tex", "rst", "org" },
  -- null_ls.generator creates an async source
  -- that spawns the command with the given arguments and options
  generator = null_ls.generator({
    command = "cspell",
    args = {
      "--no-progress",
      "--no-summary",
      -- "--no-cache",
      "--config",
      (utils.home_directory() .. "/.config/nvim/lua/user/lsp/cspell.json"),
      "$FILENAME",
    },
    to_stdin = false,
    from_stderr = false,
    to_temp_file = true,
    -- choose an output format (raw, json, or line)
    format = "raw",
    check_exit_code = function(code, stderr)
      local success = code <= 1

      if not success then
        print(stderr)
      end

      return success
    end,
    on_output = function(params, done)
      local diagnostics = {}
      if not params.output then
        return done(diagnostics)
      end

      for output in params.output:gmatch("[^\r\n]+") do
        local pat_diag = "([^:]*):([^:]*):([^ ]*)([^%a]*)(.*)"
        for _junk, row, col, _junk2, message in (output):gmatch(pat_diag) do
          row = tonumber(row)
          col = tonumber(col)
          local word = message:match("%((%a+)%)")
          local misspelled_len = 1
          if word ~= nil then
            misspelled_len = word:len()
          end
          table.insert(diagnostics, {
            row = row,
            col = col,
            end_col = col + misspelled_len,
            source = "cspell",
            message = message,
            severity = 2,
          })
        end
      end
      return done(diagnostics)
    end,
  }),
}

-- null_ls.register(cspell)
utils = require("user.utils")
null_ls.setup({
  debug = false,
  temp_dir = utils.temp_directory(),
  sources = {
    formatting.stylua,
    -- formatting.rustfmt,
    formatting.eslint_d,
    formatting.yapf,
    formatting.isort,
    formatting.ruff,
    diagnostics.eslint_d,
    -- golang fix imports
    formatting.goimports,
    -- golang stricter format than gofmt - with backwards compatibility
    formatting.gofumpt,
    -- cspell,
    diagnostics.cspell.with {
      filetypes = { "markdown", "text", "latex", "tex", "rst", "org" },
    },
    -- diagnostics.flake8,
    -- pipx install codespell
    -- diagnostics.codespell,
    -- null_ls.builtins.completion.spell,
    -- diagnostics.mypy
    -- null_ls.builtins.code_actions.gitsigns,
  },
})
