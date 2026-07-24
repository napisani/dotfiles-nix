// Merges + prunes a managed key in a TOML config file. Same contract and
// tracked-state-diff logic as apply-managed-json-keys.js — see that file
// and ./lib/managed-state.js for the rationale. Requires the `@iarna/toml`
// npm package (parse + stringify; the plain `toml` package only parses)
// declared in ./package.json and installed into ./node_modules by the
// calling activation script, so Node's normal module resolution finds it
// with no global install or NODE_PATH.
//
// Env vars: same as apply-managed-json-keys.js (TARGET_FILE, MANAGED_KEY,
// DECLARED_ENTRIES, STATE_FILE).

const fs = require("node:fs");
const { atomicWriteFileSync, readManagedState, writeManagedState } = require("./lib/managed-state.js");

const targetFile = process.env.TARGET_FILE;
const managedKey = process.env.MANAGED_KEY;
const declared = JSON.parse(process.env.DECLARED_ENTRIES);
const stateFile = process.env.STATE_FILE;

let TOML = null;
try {
  TOML = require("@iarna/toml");
} catch (e) {
  console.error(
    "agents: '@iarna/toml' not found — skipping TOML update for " + targetFile + ". " +
    "Run 'npm install -g @iarna/toml' then re-run the activation to fix."
  );
  // Exit non-zero: this is a real failure to apply the declared config, not
  // a successful no-op — tooling gating on activation exit status should
  // see it as a failure.
  process.exit(1);
}

const original = fs.existsSync(targetFile) ? fs.readFileSync(targetFile, "utf8") : "";

let parsed;
try {
  parsed = original.trim() ? TOML.parse(original) : {};
} catch (e) {
  console.error("agents: refusing to update invalid TOML at " + targetFile + ": " + e.message);
  process.exit(1);
}

const { ok: stateOk, managed: previouslyManaged } = readManagedState(stateFile);
const currentManaged = new Set(Object.keys(declared));

if (!parsed[managedKey] || typeof parsed[managedKey] !== "object" || Array.isArray(parsed[managedKey])) {
  parsed[managedKey] = {};
}

let changed = false;

if (stateOk) {
  for (const name of previouslyManaged) {
    if (!currentManaged.has(name) && Object.prototype.hasOwnProperty.call(parsed[managedKey], name)) {
      delete parsed[managedKey][name];
      changed = true;
      console.log("agents: removed undeclared managed entry '" + name + "' from " + targetFile);
    }
  }
}

for (const [name, entryConfig] of Object.entries(declared)) {
  if (JSON.stringify(parsed[managedKey][name]) !== JSON.stringify(entryConfig)) {
    parsed[managedKey][name] = entryConfig;
    changed = true;
  }
}

if (changed) {
  const next = TOML.stringify(parsed);
  if (next !== original) {
    atomicWriteFileSync(targetFile, next);
    console.log("agents: applied managed '" + managedKey + "' entries -> " + targetFile);
  }
}

if (stateOk) {
  writeManagedState(stateFile, currentManaged);
}
