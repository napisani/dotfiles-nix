local vim = vim

local configured = false

local M = {}

function M.setup()
  local ok, opencode = pcall(require, "opencode")
  if not ok then
    vim.notify("opencode not found", vim.log.levels.ERROR)
    return
  end

  if configured then
    return
  end

  local ok_config, opts = pcall(require, "user.opencode")
  if not ok_config then
    vim.notify("user.opencode config missing", vim.log.levels.WARN)
    opts = {}
  end

  opencode.setup(opts)
  configured = true
end

local function prompt_with_context(context_token, opts)
  opts = opts or {}

  local ok_api, api = pcall(require, "opencode.api")
  if not ok_api then
    vim.notify("opencode.api not found", vim.log.levels.ERROR)
    return
  end

  local function run_prompt(question)
    if not question or question == "" then
      return
    end

    if context_token and context_token ~= "" and not question:find(context_token, 1, true) then
      question = question:gsub("%s*$", "") .. "\n" .. context_token
    end

    if opts.mode then
      local ok_core, core = pcall(require, "opencode.core")
      if ok_core and type(core.switch_to_mode) == "function" then
        local ok_switch, mode_promise = pcall(core.switch_to_mode, opts.mode)
        if not ok_switch then
          vim.notify("opencode mode switch failed: " .. tostring(mode_promise), vim.log.levels.ERROR)
        elseif type(mode_promise) == "table" and mode_promise.catch then
          mode_promise:catch(function(mode_err)
            vim.notify("opencode mode switch failed: " .. tostring(mode_err), vim.log.levels.ERROR)
          end)
        end
      else
        vim.notify("opencode.core not available", vim.log.levels.WARN)
      end
    end

    local prompt_promise = api.run(question, opts.run_opts)
    if type(prompt_promise) == "table" and prompt_promise.catch then
      prompt_promise:catch(function(err)
        vim.notify("opencode run failed: " .. tostring(err), vim.log.levels.ERROR)
      end)
    end
  end

  local prompt_label = opts.prompt_label or "Ask Opencode"
  local ok_snacks, Snacks = pcall(require, "snacks")
  if ok_snacks and Snacks.input then
    local snacks_opts = { prompt = prompt_label }
    if opts.snacks_input_opts then
      snacks_opts = vim.tbl_deep_extend("force", snacks_opts, opts.snacks_input_opts)
    end
    return Snacks.input(snacks_opts, function(value)
      run_prompt(value)
    end)
  end

  local question = vim.fn.input(prompt_label .. ": ")
  run_prompt(question)
end

function M.get_keymaps()
  return {
    normal = {
      { "<leader>o", group = "(o)pencode" },
      {
        "<leader>o?",
        function()
          prompt_with_context("@file", { prompt_label = "Ask Opencode" })
        end,
        desc = "(?) ask file",
      },
      {
        "<leader>oe",
        function()
          prompt_with_context("@file", { mode = "build", prompt_label = "Opencode edit" })
        end,
        desc = "(e)dit file",
      },
    },
    visual = {
      { "<leader>o", group = "(o)pencode" },
      {
        "<leader>o?",
        function()
          prompt_with_context("@selection", { prompt_label = "Ask Opencode" })
        end,
        desc = "(?) ask selection",
      },
      {
        "<leader>oe",
        function()
          prompt_with_context("@selection", { mode = "build", prompt_label = "Opencode edit" })
        end,
        desc = "(e)dit selection",
      },
    },
    shared = {},
  }
end


return M
