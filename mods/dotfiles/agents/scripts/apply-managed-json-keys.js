// Merges + prunes a managed key in a JSON config file. Tracks which entry
// names were Nix-managed on the previous run (in STATE_FILE, via
// ./lib/managed-state.js) so that removing a Nix declaration actually
// removes the entry on the next run — while never touching keys the user
// added by hand outside of Nix (they never appear in the managed-name
// state, so they're never pruned). Both the state file and the target file
// are written atomically (temp file + rename) so an interrupted process
// never leaves either truncated.
//
// Env vars:
//   TARGET_FILE      — path to the JSON file to merge into
//   MANAGED_KEY      — the object key within that file to manage (e.g. "mcpServers")
//   DECLARED_ENTRIES — JSON object { name: config, ... }, this run's full declared set
//   STATE_FILE       — path to a small JSON file recording the previously-managed name set

const fs = require("node:fs");
const { atomicWriteFileSync, readManagedState, writeManagedState } = require("./lib/managed-state.js");

const targetFile = process.env.TARGET_FILE;
const managedKey = process.env.MANAGED_KEY;
const declared = JSON.parse(process.env.DECLARED_ENTRIES);
const stateFile = process.env.STATE_FILE;

function readJson(file, fallback) {
  try {
    if (!fs.existsSync(file)) return fallback;
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (e) {
    console.error("agents: refusing to update invalid JSON at " + file + ": " + e.message);
    return null;
  }
}

const config = readJson(targetFile, {});
if (config === null) process.exit(1);

const { ok: stateOk, managed: previouslyManaged } = readManagedState(stateFile);
const currentManaged = new Set(Object.keys(declared));

if (!config[managedKey] || typeof config[managedKey] !== "object" || Array.isArray(config[managedKey])) {
  config[managedKey] = {};
}

let changed = false;

// Prune: remove anything that WAS Nix-managed but is no longer declared.
// Skipped entirely if the state file was unreadable — see readManagedState.
if (stateOk) {
  for (const name of previouslyManaged) {
    if (!currentManaged.has(name) && Object.prototype.hasOwnProperty.call(config[managedKey], name)) {
      delete config[managedKey][name];
      changed = true;
      console.log("agents: removed undeclared managed entry '" + name + "' from " + targetFile);
    }
  }
}

// Add/update: apply the current declared set. Safe to do even if the state
// file was unreadable — this doesn't depend on knowing prior state.
for (const [name, entryConfig] of Object.entries(declared)) {
  if (JSON.stringify(config[managedKey][name]) !== JSON.stringify(entryConfig)) {
    config[managedKey][name] = entryConfig;
    changed = true;
  }
}

if (changed) {
  const next = JSON.stringify(config, null, 2) + "\n";
  const current = fs.existsSync(targetFile) ? fs.readFileSync(targetFile, "utf8") : "";
  if (current !== next) {
    atomicWriteFileSync(targetFile, next);
    console.log("agents: applied managed '" + managedKey + "' entries -> " + targetFile);
  }
}

// Only persist the new managed set if we could actually read the old one —
// otherwise we'd overwrite a corrupted file with a "clean" one and lose the
// evidence needed to notice something was wrong.
if (stateOk) {
  writeManagedState(stateFile, currentManaged);
}
