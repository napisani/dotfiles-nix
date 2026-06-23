// Merges declarative MCP server entries into each agent's config file.
// Non-destructive: only adds/updates managed entries, never removes user-added servers.
//
// Input (env vars):
//   MCP_SOURCES — JSON array of { name, config, agents[] } objects
//   HOME        — home directory

const fs = require("node:fs");
const path = require("node:path");
const home = process.env.HOME;

const sources = JSON.parse(process.env.MCP_SOURCES);

const agentMcpFiles = {
  "claude-code": { file: path.join(home, ".claude.json"),        key: "mcpServers" },
  "cursor":      { file: path.join(home, ".cursor", "mcp.json"), key: "mcpServers" },
  "pi":          { file: path.join(home, ".pi", "agent", "mcp.json"), key: "mcpServers" },
};

function readJson(file, fallback) {
  try {
    if (!fs.existsSync(file)) return fallback;
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (e) {
    console.error("agents: refusing to update invalid JSON at " + file + ": " + e.message);
    return null;
  }
}

function writeJsonIfChanged(file, value) {
  const next = JSON.stringify(value, null, 2) + "\n";
  const current = fs.existsSync(file) ? fs.readFileSync(file, "utf8") : "";
  if (current === next) return;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, next);
  console.log("agents: applied MCP servers -> " + file);
}

for (const source of sources) {
  for (const agentId of source.agents) {
    const agentCfg = agentMcpFiles[agentId];
    if (!agentCfg) continue;

    const { file, key } = agentCfg;
    const config = readJson(file, {});
    if (config === null) continue;

    if (!config[key]) config[key] = {};
    if (JSON.stringify(config[key][source.name]) === JSON.stringify(source.config)) continue;

    config[key][source.name] = source.config;
    writeJsonIfChanged(file, config);
  }
}
