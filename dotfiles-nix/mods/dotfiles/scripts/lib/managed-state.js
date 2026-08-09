// Shared "previously Nix-managed name set" state-file handling, used by
// every diff-and-prune script (apply-managed-json-keys.js,
// apply-managed-toml-keys.js, apply-claude-plugins.js,
// apply-pi-packages.js). See docs/adr/0001-per-agent-modules.md.
//
// Also provides a generic atomic file writer used by all of the above for
// both their state file and their target config file, so a process
// interruption mid-write can never leave either file truncated.

const fs = require("node:fs");
const path = require("node:path");

// Write `content` to `file` atomically: write to a sibling temp file, then
// rename over the real path. A rename within the same directory is atomic
// on POSIX filesystems, so an interrupted process leaves either the old
// file intact or the new one fully written — never a partial file.
function atomicWriteFileSync(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = file + ".tmp." + process.pid + "." + Date.now();
  fs.writeFileSync(tmp, content);
  fs.renameSync(tmp, file);
}

// Read the "previously Nix-managed" name set from `stateFile`.
//
// Returns { ok: true, managed: Set } when the file is absent (first run —
// safe empty default) or present and valid.
//
// Returns { ok: false, managed: Set() } when the file exists but fails to
// parse. Callers must treat `ok: false` as "don't know what was previously
// managed" and skip pruning entirely this run — never silently treat
// corruption as "nothing was ever managed" (that would lose track of
// entries that genuinely need pruning) — and skip overwriting the state
// file too, so a human has something to inspect/recover rather than the
// corruption being silently paved over.
function readManagedState(stateFile) {
  if (!fs.existsSync(stateFile)) {
    return { ok: true, managed: new Set() };
  }
  try {
    const parsed = JSON.parse(fs.readFileSync(stateFile, "utf8"));
    return { ok: true, managed: new Set(Array.isArray(parsed) ? parsed : []) };
  } catch (e) {
    console.error(
      "agents: refusing to prune against unreadable state file " + stateFile + ": " + e.message +
      ". Skipping prune this run — fix or remove the file to resume tracking."
    );
    return { ok: false, managed: new Set() };
  }
}

function writeManagedState(stateFile, managedSet) {
  atomicWriteFileSync(stateFile, JSON.stringify([...managedSet].sort()) + "\n");
}

module.exports = { atomicWriteFileSync, readManagedState, writeManagedState };
