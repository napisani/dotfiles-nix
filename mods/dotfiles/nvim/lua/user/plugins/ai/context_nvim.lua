local M = {}

function M.setup()
  require("context_nvim").setup({
    enable_history = false,

    telescope = {
      enable = false,
    },

    cmp = {
      enable = false,
      manual_context_keyword = "@ctx",
    },

    blink = {
      enable = true,
      manual_context_keyword = "@ctx",
    },

    lsp = {
      ignore_sources = {
        "efm/cspell",
      },
    },

    prompts = {
      {
        cmp = "Jesttest",
        name = "jest test suite",
        prompt = "Using the code above, write a jest test suite. Please respond with only code any not explanation",
      },
    },
  })
end

function M.get_keymaps()
  return {
    normal = {
      { "<leader>aca", ":ContextNvim add_current<cr>", desc = "(A)dd context" },
      { "<leader>acl", ":ContextNvim add_line_lsp_daig<cr>", desc = "(l)sp diag to context" },
      { "<leader>acx", ":ContextNvim clear_manual<cr>", desc = "clear context" },
      { "<leader>ap", ":ContextNvim insert_prompt<cr>", desc = "insert (p)rompt" },
      { "<leader>fa", "<cmd>:ContextNvim find_context_manual<cr>", desc = "(a)i contexts" },
    },

    visual = {
      { "<leader>a", group = "AI" },
      { "<leader>aca", ":<C-u>'<,'>ContextNvim add_current<cr>", desc = "(A)dd context" },
    },

    shared = {},
  }
end

return M
