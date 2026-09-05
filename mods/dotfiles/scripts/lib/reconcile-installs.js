// Shared native-install state machine. Adapters own declarations and local
// probes; this module owns per-asset progress, retry, and managed-only pruning.
// observe(id, spec, previousSpec) returns { status: 'healthy'|'missing'|'unknown', reason? }.
// For removed IDs, spec is null and healthy means still installed.
const fs = require("node:fs");
const { atomicWriteFileSync } = require("./managed-state.js");

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

function load(file) {
  if (!fs.existsSync(file)) return Object.create(null);
  const raw = JSON.parse(fs.readFileSync(file, "utf8"));
  if (
    raw && raw.schema === 1 && raw.entries && typeof raw.entries === "object" &&
    !Array.isArray(raw.entries)
  ) {
    for (const entry of Object.values(raw.entries)) {
      if (
        !entry || !Object.hasOwn(entry, "spec") ||
        typeof entry.pending !== "boolean"
      ) {
        throw new Error("invalid per-asset state");
      }
    }
    return Object.assign(Object.create(null), raw.entries);
  }
  // Legacy array and Pi/npm convergence formats retain ownership, but must
  // pass a fresh local probe before adopting the current declaration.
  const managed = Array.isArray(raw) ? raw : raw?.managed;
  if (
    (Array.isArray(raw) ||
      (raw && raw.schema === undefined &&
        typeof raw.converged === "boolean")) &&
    Array.isArray(managed) && managed.every((id) => typeof id === "string")
  ) {
    return Object.assign(
      Object.create(null),
      Object.fromEntries(
        managed.map((id) => [id, { spec: null, pending: false }]),
      ),
    );
  }
  throw new Error("unrecognized state schema");
}

function reconcileInstalls(
  {
    stateFile,
    desired,
    observe,
    install,
    remove,
    force = false,
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
  fs.mkdirSync(require("node:path").dirname(stateFile), { recursive: true });
  const lock = stateFile + ".lock";
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
    const save = () => {
      const next = JSON.stringify({ schema: 1, entries: canonical(entries) }) +
        "\n";
      if (
        !fs.existsSync(stateFile) || fs.readFileSync(stateFile, "utf8") !== next
      ) atomicWriteFileSync(stateFile, next);
    };
    const probe = (id, spec) => {
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
    let ok = true;
    const installed = [];
    const removed = [];
    for (
      const id of Object.keys(entries).filter((id) =>
        !Object.hasOwn(desired, id)
      )
    ) {
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
          ) throw new Error("removal did not converge");
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
    for (const [id, spec] of Object.entries(desired)) {
      const previous = entries[id];
      const health = probe(id, spec);
      if (health.status === "unknown" && !force) {
        log(`reconcile: ${id}: cannot inspect: ${health.reason}`);
        ok = false;
        continue;
      }
      const changed = previous && previous.spec !== null &&
        signature(previous.spec) !== signature(spec);
      const reason = force
        ? "explicit repair/update"
        : previous?.pending
        ? "retry failed operation"
        : changed
        ? "declaration changed"
        : health.status === "missing"
        ? (health.reason || "missing installation")
        : null;
      if (reason) {
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
            throw new Error(
              `validation failed: ${after.reason || after.status}`,
            );
          }
        } catch (error) {
          log(`reconcile: ${id}: ${error.message}`);
          ok = false;
          continue;
        }
      } else {
        log(`reconcile: ${id}: healthy; no installer needed`);
      }
      entries[id] = { spec, pending: installed.includes(id) };
      save();
    }
    if (installed.length || removed.length) {
      try {
        if (finish() === false) {
          throw new Error("post-install reconciliation failed");
        }
        for (const id of installed) {
          if (probe(id, desired[id]).status === "healthy") {
            entries[id].pending = false;
          } else ok = false;
        }
        for (const id of removed) delete entries[id];
        save();
      } catch (error) {
        log(`reconcile: ${error.message}`);
        ok = false;
      }
    }
    return ok;
  } finally {
    fs.rmdirSync(lock);
  }
}
module.exports = { reconcileInstalls };
