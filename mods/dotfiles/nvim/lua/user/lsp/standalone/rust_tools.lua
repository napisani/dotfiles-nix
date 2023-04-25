local status_ok, rt = pcall(require, "rust-tools")
if not status_ok then
  vim.notify('rust-tools not found')
  return
end

local extension_path = vim.env.HOME .. '/.vscode/extensions/vadimcn.vscode-lldb-1.8.1/'
local codelldb_path = extension_path .. 'adapter/codelldb'
local liblldb_path = extension_path .. 'lldb/lib/liblldb.dylib'

local on_attach = require("user.lsp.handlers").on_attach
local opts = {
  tools = { -- rust-tools options
    autoSetHints = true,
    inlay_hints = {
      show_parameter_hints = false,
      parameter_hints_prefix = "",
      other_hints_prefix = "",
    },
  },

  -- all the opts to send to nvim-lspconfig
  -- these override the defaults set by rust-tools.nvim
  -- see https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#rust_analyzer
  server = {
    -- on_attach is a callback called when the language server attaches to the buffer
    -- on_attach = on_attach,
    on_attach = function(client, bufnr)
      on_attach(client, bufnr)
      -- Hover actions
      vim.keymap.set("n", "<C-space>", rt.hover_actions.hover_actions, { buffer = bufnr })
      -- Code action groups
      vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, { buffer = bufnr })
    end,
    settings = {
      -- to enable rust-analyzer settings visit:
      -- https://github.com/rust-analyzer/rust-analyzer/blob/master/docs/user/generated_config.adoc
      cargo = { allFeatures = true },
      ["rust-analyzer"] = {
        -- enable clippy on save
        checkOnSave = {
          command = "clippy",
          extraArgs = { "--no-deps" },
        },
        procMacro = {
          enable = true,
        },
      }
    }
  },
  -- debugging stuff
  dap = {
    -- adapter = { type = "executable",
    --   command = "lldb-vscode",
    --   name = "rt_lldb",
    -- },
    adapter = require('rust-tools.dap').get_codelldb_adapter(
            codelldb_path, liblldb_path)
  },
}

rt.setup(opts)
