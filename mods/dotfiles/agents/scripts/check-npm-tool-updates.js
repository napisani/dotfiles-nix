// Explicitly checks the registry for newer versions of declared global npm
// tools. Normal Home Manager activation never calls this script.
//
// Env vars:
//   DECLARED_TOOLS — JSON array of { name, version } declarations
//   NPM_COMMAND    — npm executable path (defaults to npm)

const { spawnSync } = require("node:child_process");

const declared = JSON.parse(process.env.DECLARED_TOOLS || "[]");
const npmCommand = process.env.NPM_COMMAND || "npm";
const updates = [];
let failed = false;

for (const tool of declared) {
  if (!tool || typeof tool.name !== "string" || typeof tool.version !== "string") {
    console.error("agents: invalid global npm tool declaration");
    process.exit(1);
  }

  const result = spawnSync(npmCommand, ["view", tool.name, "version", "--json"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    timeout: 60_000,
  });
  if (result.error || result.status !== 0) {
    console.error(`agents: failed to check ${tool.name}: ${result.error?.message || result.stderr.trim() || `npm exited ${result.status}`}`);
    failed = true;
    continue;
  }

  try {
    const latest = JSON.parse(result.stdout);
    if (typeof latest !== "string") throw new Error("expected one version string");
    if (latest !== tool.version) updates.push({ ...tool, latest });
  } catch (error) {
    console.error(`agents: invalid registry response for ${tool.name}: ${error.message}`);
    failed = true;
  }
}

if (updates.length === 0 && !failed) {
  console.log("agents: all declared global npm tools are current");
} else if (updates.length > 0) {
  console.log("agents: global npm tool updates available:");
  for (const tool of updates) {
    console.log(`  ${tool.name}  ${tool.version} -> ${tool.latest}`);
  }
  console.log("update agents.globalNpmTools in mods/agents/profiles/common.nix, then switch normally");
}

if (failed) process.exitCode = 1;
