// Merges declarative base config into ~/.claude/loancrate.json.
// Non-destructive: base values overwrite matching keys, but skill-written keys
// (e.g. linear_team_statuses, gh_username) absent from the base are preserved.
//
// Input (env vars):
//   LOANCRATE_BASE_CONFIG — JSON object of known declarative values (from nix)
//   HOME                  — home directory

const { readJsonObject: readJson, writeJsonIfChanged } = require(
  "../../scripts/lib/managed-hooks.js",
);
const path = require("node:path");
const home = process.env.HOME;

const base = JSON.parse(process.env.LOANCRATE_BASE_CONFIG);
const configFile = path.join(home, ".claude", "loancrate.json");

const live = readJson(configFile, {});
if (live === null) process.exit(1);

// Merge strategy: base top-level keys win over live values.
// For object-valued keys (e.g. team_repos), merge one level deep:
// base per-key entries win, but live keys absent from base are preserved.
const merged = { ...live };
for (const [k, v] of Object.entries(base)) {
  if (
    v !== null && typeof v === "object" && !Array.isArray(v) &&
    live[k] !== null && typeof live[k] === "object" && !Array.isArray(live[k])
  ) {
    merged[k] = { ...live[k], ...v };
  } else {
    merged[k] = v;
  }
}

writeJsonIfChanged(configFile, merged);
