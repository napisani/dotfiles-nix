// Full ownership of one key in a JSON config file: the declared entry set
// REPLACES that key wholesale each run. Sibling top-level keys the tool itself
// writes (e.g. Claude's OAuth account and history in ~/.claude.json) are
// preserved. There is no state tracking — an entry removed from the Nix
// declaration disappears on the next run because the managed key is rewritten
// from the declaration alone. Consequently, entries hand-added under the
// managed key (e.g. via `claude mcp add`) do NOT survive a rebuild: promote
// them to a Nix declaration to keep them. The target file is written
// atomically (temp file + rename) so an interrupted process never truncates it.
//
// Env vars:
//   TARGET_FILE      — path to the JSON file to own a key within
//   MANAGED_KEY      — the object key within that file to own (e.g. "mcpServers")
//   DECLARED_ENTRIES — JSON object { name: config, ... }, this run's full declared set

const fs = require("node:fs");
const { atomicWriteFileSync } = require("./lib/managed-state.js");

const targetFile = process.env.TARGET_FILE;
const managedKey = process.env.MANAGED_KEY;
const declared = JSON.parse(process.env.DECLARED_ENTRIES);

const exists = fs.existsSync(targetFile);
let config;
if (!exists) {
  config = {};
} else {
  try {
    config = JSON.parse(fs.readFileSync(targetFile, "utf8"));
  } catch (e) {
    console.error("agents: refusing to update invalid JSON at " + targetFile + ": " + e.message);
    process.exit(1);
  }
  if (typeof config !== "object" || config === null || Array.isArray(config)) {
    console.error("agents: refusing to update " + targetFile + ": top-level value is not a JSON object");
    process.exit(1);
  }
}

// Full ownership: replace the managed key with exactly the declared set.
config[managedKey] = declared;

const next = JSON.stringify(config, null, 2) + "\n";
const current = exists ? fs.readFileSync(targetFile, "utf8") : "";
if (current !== next) {
  atomicWriteFileSync(targetFile, next);
  console.log("agents: applied managed '" + managedKey + "' entries -> " + targetFile);
}
