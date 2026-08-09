// Declarative model management for a local LLM runtime. Backend-agnostic: the
// caller supplies LIST/INSTALL/REMOVE commands, so this never branches on which
// runtime it is (ollama, mlx-lm, ...). Tracked-state prune, exactly like
// apply-pi-packages.js: only models this mechanism previously installed are
// removed when they become undeclared; a model the user pulled by hand is never
// touched. See docs/adr/0002-layered-asset-management.md (Layer 2).
//
// Env vars:
//   BACKEND          — label for logs/warnings (e.g. "ollama", "mlx-lm")
//   DECLARED_MODELS  — JSON array of model ids to keep installed
//   STATE_FILE       — path to the tracked "previously-managed" name set
//   LIST_CMD         — shell command printing installed ids, one per line
//   INSTALL_CMD      — shell command; invoked as `<INSTALL_CMD> <id>`
//   REMOVE_CMD       — shell command; invoked as `<REMOVE_CMD> <id>`
//   AGENTS_WARN_FILE — optional; if set, warnings are appended for the report

const { execSync } = require("node:child_process");
const fs = require("node:fs");
const { readManagedState, writeManagedState } = require("../../scripts/lib/managed-state.js");

const backend = process.env.BACKEND || "model-runtime";
const declared = JSON.parse(process.env.DECLARED_MODELS || "[]");
const stateFile = process.env.STATE_FILE;
const listCmd = process.env.LIST_CMD;
const installCmd = process.env.INSTALL_CMD;
const removeCmd = process.env.REMOVE_CMD;

function warn(msg) {
  const line = "model-runtimes: WARNING: " + backend + ": " + msg;
  console.error(line);
  const wf = process.env.AGENTS_WARN_FILE;
  if (wf) {
    try {
      fs.appendFileSync(wf, backend + ": " + msg + "\n");
    } catch {
      /* best-effort */
    }
  }
}

// Single-quote a value for safe use in the shell command we build.
function shq(s) {
  return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

let installed;
try {
  installed = new Set(
    execSync(listCmd, { encoding: "utf8" })
      .split("\n")
      .map((s) => s.trim())
      .filter(Boolean),
  );
} catch (e) {
  // Can't tell what's installed — do nothing this run rather than guess.
  warn("could not list installed models (" + e.message + ") — skipping this run");
  process.exit(0);
}

const { ok: stateOk, managed: previouslyManaged } = readManagedState(stateFile);
const declaredSet = new Set(declared);

// Install anything declared but not present.
for (const id of declared) {
  if (!installed.has(id)) {
    try {
      execSync(installCmd + " " + shq(id), { stdio: "inherit" });
      console.log("model-runtimes: " + backend + ": installed '" + id + "'");
    } catch (e) {
      warn("failed to install '" + id + "' (" + e.message + ")");
    }
  }
}

// Prune only previously-managed models that are no longer declared. Skipped
// entirely if the state file was unreadable (don't guess, don't overwrite it).
if (stateOk) {
  for (const id of previouslyManaged) {
    if (!declaredSet.has(id) && installed.has(id)) {
      try {
        execSync(removeCmd + " " + shq(id), { stdio: "inherit" });
        console.log("model-runtimes: " + backend + ": removed undeclared '" + id + "'");
      } catch (e) {
        warn("failed to remove '" + id + "' (" + e.message + ")");
      }
    }
  }
  writeManagedState(stateFile, declaredSet);
}
