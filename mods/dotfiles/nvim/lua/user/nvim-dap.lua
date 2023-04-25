local dap_status_ok, dap = pcall(require, "dap")
local utils = require("user.utils")
if not dap_status_ok then
  vim.notify("nvim-dap not found")
  return
end

local dap_ui_status_ok, dapui = pcall(require, "dapui")
if not dap_ui_status_ok then
  vim.notify("nvim-dap-ui not found")
  return
end

dapui.setup({
  icons = { expanded = "", collapsed = "", current_frame = "" },
  mappings = {
    -- Use a table to apply multiple mappings
    expand = { "<CR>", "<2-LeftMouse>" },
    open = "o",
    remove = "d",
    edit = "e",
    repl = "r",
    toggle = "t",
  },
  -- Use this to override mappings for specific elements
  element_mappings = {
    -- Example:
    -- stacks = {
    --   open = "<CR>",
    --   expand = "o",
    -- }
  },
  -- Expand lines larger than the window
  -- Requires >= 0.7
  expand_lines = vim.fn.has("nvim-0.7") == 1,
  -- Layouts define sections of the screen to place windows.
  -- The position can be "left", "right", "top" or "bottom".
  -- The size specifies the height/width depending on position. It can be an Int
  -- or a Float. Integer specifies height/width directly (i.e. 20 lines/columns) while
  -- Float value specifies percentage (i.e. 0.3 - 30% of available lines/columns)
  -- Elements are the elements shown in the layout (in order).
  -- Layouts are opened in order so that earlier layouts take priority in window sizing.
  layouts = {
    {
      elements = {
        -- Elements can be strings or table with id and size keys.
        { id = "scopes", size = 0.25 },
        "breakpoints",
        "stacks",
        "watches",
      },
      size = 60, -- 60 columns
      position = "left",
    },
    {
      elements = {
        "repl",
        "console",
      },
      size = 0.25, -- 25% of total lines
      position = "bottom",
    },
  },
  controls = {
    -- Requires Neovim nightly (or 0.8 when released)
    enabled = true,
    -- Display controls in this element
    element = "repl",
    icons = {
      -- expanded = "▾",
      -- collapsed = "▸",
      pause = "",
      play = "",
      step_into = "",
      step_over = "",
      step_out = "",
      step_back = "",
      run_last = "",
      terminate = "",
    },
  },
  floating = {
    max_height = nil,  -- These can be integers or a float between 0 and 1.
    max_width = nil,   -- Floats will be treated as percentage of your screen.
    border = "single", -- Border style. Can be "single", "double" or "rounded"
    mappings = {
      close = { "q", "<Esc>" },
    },
  },
  windows = { indent = 1 },
  render = {
    max_type_length = nil, -- Can be integer or nil.
    max_value_lines = 100, -- Can be integer or nil.
  },
})

-- dapui.setup()
-- dapui.setup {
--   icons = { expanded = "▾", collapsed = "▸" },
--   mappings = {
--     -- Use a table to apply multiple mappings
--     expand = { "<CR>", "<2-LeftMouse>" },
--     open = "o",
--     remove = "d",
--     edit = "e",
--     repl = "r",
--     toggle = "t",
--   },
--   -- Expand lines larger than the window
--   -- Requires >= 0.7
--   expand_lines = vim.fn.has "nvim-0.7",
--   -- Layouts define sections of the screen to place windows.
--   -- The position can be "left", "right", "top" or "bottom".
--   -- The size specifies the height/width depending on position. It can be an Int
--   -- or a Float. Integer specifies height/width directly (i.e. 20 lines/columns) while
--   -- Float value specifies percentage (i.e. 0.3 - 30% of available lines/columns)
--   -- Elements are the elements shown in the layout (in order).
--   -- Layouts are opened in order so that earlier layouts take priority in window sizing.
--   layouts = {
--     {
--       elements = {
--         -- Elements can be strings or table with id and size keys.
--         { id = "scopes", size = 0.25 },
--         "breakpoints",
--         -- "stacks",
--         -- "watches",
--       },
--       size = 40, -- 40 columns
--       position = "right",
--     },
--     {
--       elements = {
--         "repl",
--         "console",
--       },
--       size = 0.25, -- 25% of total lines
--       position = "bottom",
--     },
--   },
--   floating = {
--     max_height = nil, -- These can be integers or a float between 0 and 1.
--     max_width = nil, -- Floats will be treated as percentage of your screen.
--     border = "single", -- Border style. Can be "single", "double" or "rounded"
--     mappings = {
--       close = { "q", "<Esc>" },
--     },
--   },
--   windows = { indent = 1 },
--   render = {
--     max_type_length = nil, -- Can be integer or nil.
--   },
-- }

-- local icons = require "user.icons"

-- vim.fn.sign_define("DapBreakpoint", { text = icons.ui.Bug, texthl = "DiagnosticSignError", linehl = "", numhl = "" })

dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open({})
end
dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close({})
end
dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close({})
end

-- RUST DAP
local M = {}
local status_ok_rt, rt_dap = pcall(require, "rust-tools.dap")
if status_ok_rt then
  function M.run_rust()
    vim.notify("starting")
    rt_dap.start({
      executableArgs = {
        "/Users/nick/.config/nvim/lua/user/plugins.lua",
      },
      cargoArgs = {
        "run",
      },
    })
  end
end

local neotest_status, neotest = pcall(require, "neotest")
if not neotest_status then
  vim.notify("neotest not found")
  return
end

-- DAP python
-- you must first: `pip install debugpy` into you current venv

-- local rooter = require("user.nvim-rooter")
dap.adapters.python = {
  type = "executable",
  -- command = 'path/to/virtualenvs/debugpy/bin/python';
  command = utils.python_path(),
  args = { "-m", "debugpy.adapter" },
  options = {
    env = {
      PYTHONPATH = "./",
    }, -- Set the environment variables for the command
    -- cwd = rooter.get_root_dir(), -- Set the working directory for the command
    cwd = "/Users/nick/code/clearing-app2/api",
  },
}
dap.adapters.generic_remote = function(callback, config)
  local dap_conn_str = vim.fn.input("DAP server (empty cancels): ", "127.0.0.1:9001")

  if #dap_conn_str == 0 then
    print("DAP connection canceled.")
    return
  end

  local dap_host, dap_port
  local dap_conn_parts = vim.fn.split(dap_conn_str, ":", true)
  if #dap_conn_parts == 1 then
    dap_host = dap_conn_parts[1]
    dap_port = 9001
  elseif #dap_conn_parts == 2 then
    dap_host = dap_conn_parts[1]
    dap_port = dap_conn_parts[2]
  else
    vim.api.nvim_err_writeln("Invalid DAP server authority: " .. dap_conn_str)
    return
  end

  callback({
    type = "server",
    host = dap_host,
    port = dap_port,
  })

  print(string.format("Connected to: %s:%d", dap_host, dap_port))
end

dap.configurations.python = {
  {
    type = "generic_remote",
    name = "Generic remote",
    request = "attach",
    justMyCode = false,
  },
  {
    type = "python",
    name = "Launch file - auto-detect python",
    request = "launch",
    program = "${file}",
    pythonPath = utils.python_path(),
    justMyCode = false,
    env = {
      PYTHONPATH = "./",
    }, -- Set the environment variables for the command
    cwd = "/Users/nick/code/clearing-app2/api",

  },
  {
    type = "python",
    name = "flask",
    pythonPath = utils.python_path(),
    request = "launch",
    module = "flask",
    justMyCode = false,
    args = { "run", "--no-debugger", "--no-reload", '-h', '0.0.0.0', '-p', '8080', '--cert', 'localhost.pem', '--key',
      'localhost-key.pem' },
    env = {
      DEVELOPMENT_NATIVE = "1",
      FLASK_DEBUG = "1",
      GOOGLE_APPLICATION_CREDENTIALS = "/Users/nick/code/clearing-app2/api/google-key.json",
    },
  }
}
-- local extension_path = vim.env.HOME .. '/.vscode/extensions/vadimcn.vscode-lldb-1.8.1/'
-- local codelldb_path = extension_path .. 'adapter/codelldb'
-- local liblldb_path = extension_path .. 'lldb/lib/liblldb.dylib'
-- dap.adapters.lldb = {
--   type = 'executable',
--   command = codelldb_path,
--   name = 'lldb'
-- }

-- require('dap-python').setup('python')
neotest.setup({
  adapters = {
    -- require("neotest-plenary"),
    require("neotest-rust"),
    require("neotest-python")({
      -- Extra arguments for nvim-dap configuration
      -- See https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for values
      dap = { justMyCode = false },
      -- Command line arguments for runner
      -- Can also be a function to return dynamic values
      args = { "--log-level", "DEBUG", "-s" },
      -- Runner to use. Will use pytest if available by default.
      -- Can be a function to return dynamic value.
      runner = "pytest",
      -- Custom python path for the runner.
      -- Can be a string or a list of strings.
      -- Can also be a function to return dynamic value.
      -- If not provided, the path will be inferred by checking for
      -- virtual envs in the local directory and for Pipenev/Poetry configs
      python = utils.python_path(),
      -- Returns if a given file path is a test file.
      -- NB: This function is called a lot so don't perform any heavy tasks within it.
      -- is_test_file = function(file_path)
      -- end,
    }),
  },
})
--dap.configurations.cpp = {
--  {
--    name = 'Launch',
--    type = 'lldb',
--    request = 'launch',
--    program = function()
--      return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
--    end,
--    cwd = '${workspaceFolder}',
--    stopOnEntry = false,
--    args = {},

--    -- 💀
--    -- if you change `runInTerminal` to true, you might need to change the yama/ptrace_scope setting:
--    --
--    --    echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
--    --
--    -- Otherwise you might get the following error:
--    --
--    --    Error on launch: Failed to attach to the target process
--    --
--    -- But you should be aware of the implications:
--    -- https://www.kernel.org/doc/html/latest/admin-guide/LSM/Yama.html
--    -- runInTerminal = false,
--  },
--}

---- If you want to use this for Rust and C, add something like this:

--dap.configurations.c = dap.configurations.cpp
--dap.configurations.rust = dap.configurations.cpp
-- local codicons = require('codicons')
-- codicons.setup({
--   -- -- Override by mapping name to icon
--   -- ['account'] = '',
--   -- -- Or by name to hexadecimal/decimal value
--   -- ['comment'] = 0xEA6B, -- hexadecimal
--   -- ['archive'] = 60056, -- decimal
-- })
