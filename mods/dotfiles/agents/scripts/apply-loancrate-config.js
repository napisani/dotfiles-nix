// Merges declarative base config into ~/.claude/loancrate.json.
// Non-destructive: base values overwrite matching keys, but skill-written keys
// (e.g. linear_team_statuses, gh_username) absent from the base are preserved.
//
// Input (env vars):
//   LOANCRATE_BASE_CONFIG — JSON object of known declarative values (from nix)
//   HOME                  — home directory

const fs = require("node:fs");
const path = require("node:path");
const home = process.env.HOME;

const base = JSON.parse(process.env.LOANCRATE_BASE_CONFIG);
const configFile = path.join(home, ".claude", "loancrate.json");

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
  console.log("agents: applied loancrate config -> " + file);
}

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
