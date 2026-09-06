// Shared atomic file writing plus the simple "previously Nix-managed name
// set" state format used by generic diff-and-prune scripts. Pi packages reuse
// the atomic writer but keep an installer-owned convergence-aware state schema.
// See docs/adr/0001-per-agent-modules.md.
//
// Atomic replacement ensures a process interruption mid-write leaves either
// the old file or the complete new file, never a truncated target or state.

const fs = require("node:fs");
const path = require("node:path");

// Write `content` to `file` atomically: write to a sibling temp file, then
// rename over the real path. A rename within the same directory is atomic
// on POSIX filesystems, so an interrupted process leaves either the old
// file intact or the new one fully written — never a partial file.
function atomicWriteFileSync(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = file + ".tmp." + process.pid + "." + Date.now();
  // Preserve private config permissions. New files and migrated symlinks
  // start private; never copy a read-only Nix store target's mode.
  const stat = fs.existsSync(file) ? fs.lstatSync(file) : null;
  const mode = stat?.isFile() ? stat.mode & 0o777 : 0o600;
  const fd = fs.openSync(tmp, "wx", mode);
  try {
    try {
      fs.writeFileSync(fd, content);
    } finally {
      fs.closeSync(fd);
    }
    fs.renameSync(tmp, file);
  } finally {
    if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
  }
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
      "agents: refusing to prune against unreadable state file " + stateFile +
        ": " + e.message +
        ". Skipping prune this run — fix or remove the file to resume tracking.",
    );
    return { ok: false, managed: new Set() };
  }
}

function writeManagedState(stateFile, managedSet) {
  atomicWriteFileSync(stateFile, JSON.stringify([...managedSet].sort()) + "\n");
}

module.exports = { atomicWriteFileSync, readManagedState, writeManagedState };
