return {
  cmd = { "pylsp" },
  filetypes = { "python" },
  settings = {
    pylsp = {
      configurationSources = { "flake8" },
      plugins = {
        flake8 = { enabled = true,
          -- ignore = { "E203" },
          maxLineLength = 120
        },
        jedi_completion = { enabled = true },
        jedi_definition = { enabled = true },
        jedi_hover = { enabled = true },
        jedi_references = { enabled = true },
        jedi_signature_help = { enabled = true },
        jedi_symbols = { enabled = true, all_scopes = true },
        mccabe = { enabled = false },
        pycodestyle = { enabled = false },
        pyflakes = { enabled = false },
        yapf = { enabled = true },
      },

    },

  },

}
