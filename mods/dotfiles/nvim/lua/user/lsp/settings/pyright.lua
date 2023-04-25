local util = require('lspconfig').util
return {
  flags = { debounce_text_changes = 150 },
  root_dir = util.root_pattern('.venv', '.envrc', 'requirements.txt', 'venv', 'pyrightconfig.json'),
  filetypes = { "python" },
  settings = {
    pyright = {
      -- disableLanguageServices = false,
      -- disableOrganizeImports = true
    },
    python = {
      analysis = {
        useLibraryCodeForTypes = true,
        -- diagnosticMode = "workspace",
        diagnosticMode = "openfile",
        inlayHints = {
          variableTypes = true,
          functionReturnTypes = true,
        },
      },
    },
  }
}
