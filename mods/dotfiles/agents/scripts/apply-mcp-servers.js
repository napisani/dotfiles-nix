// Merges declarative MCP server entries into each agent's config file.
// Non-destructive: only adds/updates managed entries, never removes user-added servers.
//
// Input (env vars):
//   MCP_SOURCES — JSON array of { name, config, agents[] } objects
//   HOME        — home directory
//
// Codex's ~/.codex/config.toml requires the `@iarna/toml` npm package
// (parse + stringify; the plain `toml` package only parses). It's declared
// in ./package.json and installed into ./node_modules by the calling
// activation script (mcp.nix), so Node's normal module resolution finds it
// with no global install or NODE_PATH needed. Codex MCP entries are skipped
// with a warning if it's ever unresolvable (e.g. that install step failed).

const fs = require("node:fs");
const path = require("node:path");
const home = process.env.HOME;

const sources = JSON.parse(process.env.MCP_SOURCES);

let TOML = null;
try {
  TOML = require("@iarna/toml");
} catch (e) {
  // Left null; handled per-call below so JSON-based agents still get applied.
}

const agentMcpFiles = {
  "claude-code": { file: path.join(home, ".claude.json"),        key: "mcpServers" },
  "pi":          { file: path.join(home, ".pi", "agent", "mcp.json"), key: "mcpServers" },
};

const codexConfigFile = path.join(home, ".codex", "config.toml");

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

// ── Codex: TOML `[mcp_servers.<name>]` tables ───────────────────────────────
// Codex has no JSON config file, so MCP servers targeting it are merged
// directly into ~/.codex/config.toml via a real TOML parser. Non-destructive:
// only the managed server's own key is ever replaced; everything else in the
// parsed document (e.g. `[features]`, `[hooks.state.*]`) round-trips as-is.

function upsertCodexMcpServer(configFile, name, config) {
  if (!TOML) {
    console.error(
      "agents: '@iarna/toml' not found — skipping Codex MCP server '" + name + "'. " +
      "Run 'npm install -g @iarna/toml' then re-run the activation to fix."
    );
    return;
  }

  const original = fs.existsSync(configFile) ? fs.readFileSync(configFile, "utf8") : "";

  let parsed;
  try {
    parsed = original.trim() ? TOML.parse(original) : {};
  } catch (e) {
    console.error("agents: refusing to update invalid TOML at " + configFile + ": " + e.message);
    return;
  }

  if (!parsed.mcp_servers || typeof parsed.mcp_servers !== "object") parsed.mcp_servers = {};
  if (JSON.stringify(parsed.mcp_servers[name]) === JSON.stringify(config)) return;

  parsed.mcp_servers[name] = config;

  const next = TOML.stringify(parsed);
  if (next === original) return;
  fs.mkdirSync(path.dirname(configFile), { recursive: true });
  fs.writeFileSync(configFile, next);
  console.log("agents: applied MCP server '" + name + "' -> " + configFile);
}

for (const source of sources) {
  for (const agentId of source.agents) {
    if (agentId === "codex") {
      upsertCodexMcpServer(codexConfigFile, source.name, source.config);
      continue;
    }

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
