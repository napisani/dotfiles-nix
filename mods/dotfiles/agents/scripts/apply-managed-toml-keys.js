// Full ownership of one key in a TOML config file: the declared entry set
// REPLACES that key wholesale each run. Same contract as
// apply-managed-json-keys.js — see that file for the rationale (sibling keys
// the tool writes are preserved; entries hand-added under the managed key do
// not survive; no state tracking). Requires the `@iarna/toml` npm package
// (parse + stringify; the plain `toml` package only parses), declared in
// ./package.json and installed into ./node_modules by the calling activation
// script, so Node's normal module resolution finds it with no global install.
//
// Env vars: TARGET_FILE, MANAGED_KEY, DECLARED_ENTRIES.

const fs = require("node:fs");
const { atomicWriteFileSync } = require("./lib/managed-state.js");

const targetFile = process.env.TARGET_FILE;
const managedKey = process.env.MANAGED_KEY;
const declared = JSON.parse(process.env.DECLARED_ENTRIES);

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

const exists = fs.existsSync(targetFile);
const original = exists ? fs.readFileSync(targetFile, "utf8") : "";

let parsed;
try {
  parsed = original.trim() ? TOML.parse(original) : {};
} catch (e) {
  console.error("agents: refusing to update invalid TOML at " + targetFile + ": " + e.message);
  process.exit(1);
}

// Full ownership: replace the managed key with exactly the declared set.
parsed[managedKey] = declared;

const next = TOML.stringify(parsed);
if (next !== original) {
  atomicWriteFileSync(targetFile, next);
  console.log("agents: applied managed '" + managedKey + "' entries -> " + targetFile);
}
