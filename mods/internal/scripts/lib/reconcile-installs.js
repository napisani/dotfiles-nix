// Shared native-install state machine. Adapters own declarations and local
// probes; this module owns per-asset progress, retry, and managed-only pruning.
// observe(id, spec, previousSpec) returns { status: 'healthy'|'missing'|'unknown', reason? }.
// For removed IDs, spec is null and healthy means still installed.
const fs = require("node:fs");
const path = require("node:path");
const { atomicWriteFileSync } = require("./managed-state.js");

// ── State signatures ────────────────────────────────────────────────────────
// A stable, order-independent serialization so re-declaring the same spec in a
// different key order does not read as drift.
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value).sort().map((key) => [key, canonical(value[key])]),
    );
  }
  return value;
}
const signature = (value) => JSON.stringify(canonical(value));

// True when a tracked entry carries a real spec that no longer matches the
// declaration. A legacy-adopted entry (spec === null) is intentionally NOT
// treated as changed here, so it is adopted rather than reinstalled.
const specChanged = (previous, spec) =>
  Boolean(previous) && previous.spec !== null &&
  signature(previous.spec) !== signature(spec);

const emptyState = () => Object.create(null);

// ── State persistence ───────────────────────────────────────────────────────
// Read the tracked per-asset state, migrating the two historical formats.
// Throws on anything unrecognized so callers can refuse to mutate blindly.
function load(file) {
  if (!fs.existsSync(file)) return emptyState();
  const raw = JSON.parse(fs.readFileSync(file, "utf8"));
  const current = parseCurrentSchema(raw);
  if (current) return current;
  const adopted = adoptLegacy(raw);
  if (adopted) return adopted;
  throw new Error("unrecognized state schema");
}

function parseCurrentSchema(raw) {
  const isSchemaOne = raw && raw.schema === 1 && raw.entries &&
    typeof raw.entries === "object" && !Array.isArray(raw.entries);
  if (!isSchemaOne) return null;
  for (const entry of Object.values(raw.entries)) {
    if (
      !entry || !Object.hasOwn(entry, "spec") ||
      typeof entry.pending !== "boolean"
    ) {
      throw new Error("invalid per-asset state");
    }
  }
  return Object.assign(emptyState(), raw.entries);
}

// Legacy array and Pi/npm convergence formats retain ownership, but each ID is
// stored with a null spec so a fresh local probe must pass before adoption.
function adoptLegacy(raw) {
  const managed = Array.isArray(raw) ? raw : raw?.managed;
  const recognized = Array.isArray(raw) ||
    (raw && raw.schema === undefined && typeof raw.converged === "boolean");
  if (
    !recognized || !Array.isArray(managed) ||
    !managed.every((id) => typeof id === "string")
  ) {
    return null;
  }
  return Object.assign(
    emptyState(),
    Object.fromEntries(managed.map((id) => [id, { spec: null, pending: false }])),
  );
}

// ── Public entry point ──────────────────────────────────────────────────────
function reconcileInstalls(
  {
    stateFile,
    desired,
    observe,
    install,
    remove,
    force = false,
    mode = "apply",
    finish = () => {},
    log = console.log,
  },
) {
  if (
    !stateFile || !desired || Array.isArray(desired) ||
    typeof desired !== "object"
  ) {
    throw new Error("stateFile and desired asset map are required");
  }
  if (!["apply", "status"].includes(mode)) {
    throw new Error(`invalid reconciliation mode: ${mode}`);
  }
  const lock = stateFile + ".lock";
  return mode === "status"
    ? inspectStatus({ stateFile, desired, observe, log, lock })
    : applyReconciliation({
      stateFile,
      desired,
      observe,
      install,
      remove,
      force,
      finish,
      log,
      lock,
    });
}

// ── Status mode (read-only) ─────────────────────────────────────────────────
function inspectStatus({ stateFile, desired, observe, log, lock }) {
  try {
    if (fs.existsSync(lock)) throw new Error(`state locked at ${lock}`);
    const entries = load(stateFile);
    let ok = true;
    const ids = new Set([...Object.keys(entries), ...Object.keys(desired)]);
    for (const id of ids) {
      const spec = Object.hasOwn(desired, id) ? desired[id] : null;
      const status = statusFor({ id, spec, previous: entries[id], observe });
      log(`reconcile: ${id}: ${status}`);
      if (status !== "healthy") ok = false;
    }
    return ok;
  } catch (error) {
    log(`reconcile: cannot inspect ${stateFile}: ${error.message}`);
    return false;
  }
}

// The human-readable status of a single asset. A throwing/invalid probe becomes
// "unknown: <reason>"; a non-throwing "unknown" probe is reported bare.
function statusFor({ id, spec, previous, observe }) {
  try {
    const health = observe(id, spec, previous?.spec);
    const status = health?.status;
    if (!["healthy", "missing", "unknown"].includes(status)) {
      throw new Error("invalid probe result");
    }
    if (spec === null) return "removal pending";
    if (status !== "healthy") return status;
    if (!previous) return "untracked";
    if (previous.pending) return "retry pending";
    if (previous.spec === null || specChanged(previous, spec)) {
      return "declaration changed";
    }
    return "healthy";
  } catch (error) {
    return `unknown: ${error.message}`;
  }
}

// ── Apply mode (mutating, lock-guarded) ─────────────────────────────────────
function applyReconciliation(
  { stateFile, desired, observe, install, remove, force, finish, log, lock },
) {
  fs.mkdirSync(path.dirname(stateFile), { recursive: true });
  try {
    fs.mkdirSync(lock);
  } catch (error) {
    log(
      `reconcile: state locked at ${lock}; another activation may be running (remove only after confirming it stopped)`,
    );
    return false;
  }
  try {
    let entries;
    try {
      entries = load(stateFile);
    } catch (error) {
      log(
        `reconcile: refusing mutations with unreadable state ${stateFile}: ${error.message}`,
      );
      return false;
    }
    const save = makeSave(stateFile, entries);
    const probe = makeProbe(observe, entries);
    const installed = [];
    const removed = [];
    const removalsOk = pruneUndeclared(
      { entries, desired, probe, remove, save, removed, log },
    );
    const installsOk = installDeclared(
      { entries, desired, probe, install, force, save, installed, log },
    );
    const finalizeOk = finalize(
      { entries, desired, probe, finish, installed, removed, save, log },
    );
    return removalsOk && installsOk && finalizeOk;
  } finally {
    fs.rmdirSync(lock);
  }
}

// Persist the current entries, but only when the bytes actually change.
function makeSave(stateFile, entries) {
  return () => {
    const next =
      JSON.stringify({ schema: 1, entries: canonical(entries) }) + "\n";
    if (
      !fs.existsSync(stateFile) || fs.readFileSync(stateFile, "utf8") !== next
    ) {
      atomicWriteFileSync(stateFile, next);
    }
  };
}

// Wrap the caller's probe so an invalid/throwing result reads as "unknown"
// rather than crashing the run — uncertainty must never authorize a mutation.
function makeProbe(observe, entries) {
  return (id, spec) => {
    try {
      const result = observe(id, spec, entries[id]?.spec);
      if (!["healthy", "missing", "unknown"].includes(result?.status)) {
        throw new Error("invalid probe result");
      }
      return result;
    } catch (error) {
      return { status: "unknown", reason: error.message };
    }
  };
}

// Remove entries that dropped out of the declaration, retrying failed removals.
function pruneUndeclared(
  { entries, desired, probe, remove, save, removed, log },
) {
  let ok = true;
  const undeclared = Object.keys(entries).filter(
    (id) => !Object.hasOwn(desired, id),
  );
  for (const id of undeclared) {
    const health = probe(id, null);
    if (health.status === "unknown") {
      log(`reconcile: ${id}: cannot inspect removal: ${health.reason}`);
      ok = false;
      continue;
    }
    if (health.status !== "missing") {
      log(`reconcile: ${id}: removed from declaration`);
      entries[id].pending = true;
      save();
      try {
        if (
          remove(id, entries[id].spec) === false ||
          probe(id, null).status !== "missing"
        ) {
          throw new Error("removal did not converge");
        }
      } catch (error) {
        log(`reconcile: ${id}: ${error.message}`);
        ok = false;
        continue;
      }
    }
    entries[id].pending = true;
    removed.push(id);
    save();
  }
  return ok;
}

// Why (if at all) a declared asset needs its installer run this pass.
function installReason({ previous, spec, health, force }) {
  if (force) return "explicit repair/update";
  if (previous?.pending) return "retry failed operation";
  if (specChanged(previous, spec)) return "declaration changed";
  if (health.status === "missing") return health.reason || "missing installation";
  return null;
}

// Install/repair each declared asset, validating the result before clearing its
// pending flag in finalize().
function installDeclared(
  { entries, desired, probe, install, force, save, installed, log },
) {
  let ok = true;
  for (const [id, spec] of Object.entries(desired)) {
    const previous = entries[id];
    const health = probe(id, spec);
    if (health.status === "unknown" && !force) {
      log(`reconcile: ${id}: cannot inspect: ${health.reason}`);
      ok = false;
      continue;
    }
    const reason = installReason({ previous, spec, health, force });
    if (!reason) {
      log(`reconcile: ${id}: healthy; no installer needed`);
      entries[id] = { spec, pending: installed.includes(id) };
      save();
      continue;
    }
    log(`reconcile: ${id}: ${reason}`);
    // Preserve ownership of successful installs even when post-validation
    // fails. A failed first install does not authorize subsequent pruning.
    if (previous) {
      previous.pending = true;
      save();
    }
    try {
      if (install(id, spec) === false) throw new Error("installer failed");
      entries[id] = { spec, pending: true };
      installed.push(id);
      save();
      const after = probe(id, spec);
      if (after.status !== "healthy") {
        throw new Error(`validation failed: ${after.reason || after.status}`);
      }
    } catch (error) {
      log(`reconcile: ${id}: ${error.message}`);
      ok = false;
      continue;
    }
    entries[id] = { spec, pending: installed.includes(id) };
    save();
  }
  return ok;
}

// After any mutation, run the caller's post-step, then clear pending flags for
// validated installs and forget removed entries. Skipped when nothing changed.
function finalize(
  { entries, desired, probe, finish, installed, removed, save, log },
) {
  if (!installed.length && !removed.length) return true;
  try {
    if (finish() === false) {
      throw new Error("post-install reconciliation failed");
    }
    let ok = true;
    for (const id of installed) {
      if (probe(id, desired[id]).status === "healthy") {
        entries[id].pending = false;
      } else ok = false;
    }
    for (const id of removed) delete entries[id];
    save();
    return ok;
  } catch (error) {
    log(`reconcile: ${error.message}`);
    return false;
  }
}

module.exports = { reconcileInstalls };
