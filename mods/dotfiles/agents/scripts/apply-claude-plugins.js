// Reconciles declared Claude Code plugins while keeping routine activation
// local. Healthy unchanged declarations only run `claude plugin list --json`;
// marketplace and install/update commands run only for declaration changes,
// repair, or an explicit update.
//
// Env vars:
//   MARKETPLACES     — JSON array of marketplace source strings
//   DECLARED_PLUGINS — JSON array of "<plugin>@<marketplace>" specs
//   STATE_FILE       — convergence and managed-plugin state
//   FORCE_REPAIR     — truthy value reinstalls declared plugins
//   UPDATE           — truthy value refreshes marketplaces and plugins

const crypto = require("node:crypto");
const fs = require("node:fs");
const { spawnSync } = require("node:child_process");
const { atomicWriteFileSync } = require("../../scripts/lib/managed-state.js");

const marketplaces = JSON.parse(process.env.MARKETPLACES || "[]");
const declaredPlugins = JSON.parse(process.env.DECLARED_PLUGINS || "[]");
const stateFile = process.env.STATE_FILE;
const forceRepair = /^(1|true|yes)$/i.test(process.env.FORCE_REPAIR || "");
const update = /^(1|true|yes)$/i.test(process.env.UPDATE || "");
const EXEC_TIMEOUT_MS = 60_000;

const canonical = (values) => [...new Set(values)].sort();
const fingerprint = () => crypto.createHash("sha256").update(JSON.stringify({
  marketplaces: canonical(marketplaces),
  plugins: canonical(declaredPlugins),
})).digest("hex");

function readState() {
  if (!fs.existsSync(stateFile)) {
    return { ok: true, converged: false, fingerprint: null, managed: new Set() };
  }
  try {
    const parsed = JSON.parse(fs.readFileSync(stateFile, "utf8"));
    if (Array.isArray(parsed) && parsed.every((value) => typeof value === "string")) {
      return { ok: true, converged: false, fingerprint: null, managed: new Set(parsed) };
    }
    if (
      parsed && typeof parsed.converged === "boolean" &&
      typeof parsed.declarationFingerprint === "string" &&
      Array.isArray(parsed.managed) && parsed.managed.every((value) => typeof value === "string")
    ) {
      return {
        ok: true,
        converged: parsed.converged,
        fingerprint: parsed.declarationFingerprint,
        managed: new Set(parsed.managed),
      };
    }
    throw new Error("unrecognized Claude plugin state format");
  } catch (error) {
    console.error(`agents: refusing to prune against unreadable Claude plugin state ${stateFile}: ${error.message}`);
    return { ok: false, converged: false, fingerprint: null, managed: new Set() };
  }
}

function writeState(managed, converged) {
  atomicWriteFileSync(stateFile, JSON.stringify({
    converged,
    declarationFingerprint: fingerprint(),
    managed: canonical(managed),
  }) + "\n");
}

function run(args, capture = false) {
  console.log("agents: claude " + args.join(" "));
  const result = spawnSync("claude", args, {
    encoding: capture ? "utf8" : undefined,
    stdio: capture ? ["ignore", "pipe", "pipe"] : "inherit",
    timeout: EXEC_TIMEOUT_MS,
  });
  return { ok: !result.error && result.status === 0, result };
}

function inventory() {
  const { ok, result } = run(["plugin", "list", "--json"], true);
  if (!ok) return { usable: false, installed: new Set() };
  try {
    const entries = JSON.parse(result.stdout);
    if (!Array.isArray(entries)) throw new Error("expected an array");
    const installed = new Set(
      entries
        .filter((entry) => entry && entry.scope === "user" && typeof entry.id === "string")
        .filter((entry) => !entry.installPath || fs.existsSync(entry.installPath))
        .map((entry) => entry.id)
    );
    return { usable: true, installed };
  } catch (error) {
    console.error("agents: Claude plugin inventory returned invalid JSON: " + error.message);
    return { usable: false, installed: new Set() };
  }
}

const state = readState();
const desired = new Set(declaredPlugins);
const stale = new Set([...state.managed].filter((plugin) => !desired.has(plugin)));
const initialInventory = inventory();
const healthy = initialInventory.usable && [...desired].every((plugin) => initialInventory.installed.has(plugin));
const allDesiredManaged = [...desired].every((plugin) => state.managed.has(plugin));

if (
  !forceRepair && !update && state.ok && state.converged &&
  state.fingerprint === fingerprint() && stale.size === 0 && allDesiredManaged && healthy
) {
  console.log("agents: Claude plugins already converged; skipping reconciliation");
  process.exit(0);
}

let succeeded = state.ok;
const managedAfter = new Set(state.managed);

if (!update || state.fingerprint !== fingerprint()) {
  for (const marketplace of marketplaces) {
    if (!run(["plugin", "marketplace", "add", marketplace, "--scope", "user"]).ok) {
      succeeded = false;
    }
  }
}

if (state.ok) {
  for (const plugin of stale) {
    if (initialInventory.usable && !initialInventory.installed.has(plugin)) {
      managedAfter.delete(plugin);
    } else if (run(["plugin", "uninstall", plugin, "--scope", "user"]).ok) {
      managedAfter.delete(plugin);
    } else {
      succeeded = false;
    }
  }
}

if (update) {
  if (!run(["plugin", "marketplace", "update"]).ok) succeeded = false;
  for (const plugin of desired) {
    if (run(["plugin", "update", plugin, "--scope", "user", "--yes"]).ok) {
      managedAfter.add(plugin);
    } else {
      succeeded = false;
    }
  }
} else {
  for (const plugin of desired) {
    const needsInstall = forceRepair || !state.managed.has(plugin) ||
      !initialInventory.usable || !initialInventory.installed.has(plugin);
    if (!needsInstall) continue;
    if (forceRepair) run(["plugin", "uninstall", plugin, "--scope", "user"]);
    if (run(["plugin", "install", plugin, "--scope", "user"]).ok) {
      managedAfter.add(plugin);
    } else {
      succeeded = false;
    }
  }
}

const finalInventory = inventory();
const converged = state.ok && succeeded && finalInventory.usable &&
  [...desired].every((plugin) => finalInventory.installed.has(plugin)) &&
  [...stale].every((plugin) => !finalInventory.installed.has(plugin));

if (state.ok) writeState(converged ? desired : managedAfter, converged);
if (!converged) process.exitCode = 1;
