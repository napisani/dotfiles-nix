---@diagnostic disable: undefined-global

local M = {}

local ts_code_action_order = {
  "source.addMissingImports.ts",
  "source.removeUnused.ts",
  "source.removeUnusedImports.ts",
  "source.fixAll.ts",
}

local default_timeout_ms = 4000

local code_action_method = vim.lsp.protocol.Methods.textDocument_codeAction
  or "textDocument/codeAction"

local execute_command_method = vim.lsp.protocol.Methods.workspace_executeCommand
  or "workspace/executeCommand"

local function make_client_range_params(client, bufnr)
  local encoding = client and client.offset_encoding or "utf-16"

  local ok, params = pcall(vim.lsp.util.make_range_params, nil, encoding)
  if ok and params then
    return params
  end

  if bufnr then
    ok, params = pcall(vim.lsp.util.make_range_params, nil, bufnr)
    if ok and params then
      return params
    end
  end

  return vim.lsp.util.make_range_params()
end

local function apply_action(client, action, bufnr)
  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding or "utf-16")
  end

  if not action.command then
    return
  end

  local command = action.command
  if type(command) == "string" then
    command = { command = command }
  end

  if type(command) ~= "table" or command.command == nil then
    return
  end

  client:request(execute_command_method, command, function(err)
    if err then
      vim.notify_once(string.format("vtsls executeCommand failed: %s", err), vim.log.levels.WARN)
    end
  end, bufnr)
end

local function request_code_action(client, bufnr, kind, timeout_ms)
  local params = make_client_range_params(client, bufnr)
  params.context = {
    diagnostics = {},
    only = { kind },
  }

  local ok, result = pcall(function()
    return client:request_sync(code_action_method, params, timeout_ms or default_timeout_ms, bufnr)
  end)

  if not ok or not result or not result.result then
    return nil
  end

  return result.result
end

local function run_ts_code_action_sequence(bufnr, opts)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "vtsls" })
  if vim.tbl_isempty(clients) then
    return
  end

  local kinds = opts and opts.kinds or ts_code_action_order
  local timeout_ms = opts and opts.timeout_ms or default_timeout_ms

  for _, client in ipairs(clients) do
    for _, kind in ipairs(kinds) do
      local actions = request_code_action(client, bufnr, kind, timeout_ms)
      if actions then
        for _, action in ipairs(actions) do
          apply_action(client, action, bufnr)
        end
      end
    end
  end
end

function M.ts_organize_imports(bufnr, opts)
  run_ts_code_action_sequence(bufnr or vim.api.nvim_get_current_buf(), opts)
end

function M.gopls_organize_imports(bufnr, timeout_ms)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  timeout_ms = timeout_ms or default_timeout_ms
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = "gopls" })[1]
  local params = make_client_range_params(client, bufnr)
  params.context = { only = { "source.organizeImports" } }
  local result = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, timeout_ms)
  for _, res in pairs(result or {}) do
    for _, r in pairs(res.result or {}) do
      if r.edit then
        vim.lsp.util.apply_workspace_edit(r.edit, client and client.offset_encoding or "utf-8")
      else
        vim.lsp.buf.execute_command(r.command)
      end
    end
  end
end

return M
