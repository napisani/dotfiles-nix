local M = {}

local configured = false

local function normalize_command(cmd)
  if type(cmd) == "table" and #cmd > 0 then
    return vim.deepcopy(cmd)
  elseif type(cmd) == "string" and cmd ~= "" then
    return { vim.fn.expand(cmd) }
  end
  return {}
end

local function detect_node_command()
  local existing = normalize_command(vim.g.copilot_node_command)
  if #existing == 0 then
    existing = normalize_command(vim.env.COPILOT_NODE_COMMAND)
  end
  if #existing == 0 then
    local exepath = vim.fn.exepath("node")
    if exepath ~= "" then
      existing = { exepath }
    end
  end
  if #existing == 0 then
    existing = { "node" }
  end
  return existing
end

function M.setup()
  if configured then
    return
  end

  local env_bin = vim.fn.exepath("env")
  if env_bin == "" then
    env_bin = "env"
  end

  if vim.g.copilot_npx_command == nil then
    vim.g.copilot_npx_command = 0
  end

  local node_cmd = detect_node_command()
  vim.g.copilot_node_command = vim.list_extend({ env_bin, "NODE_OPTIONS=--experimental-sqlite" }, node_cmd)
  configured = true
end

return M
