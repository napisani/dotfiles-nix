// Reconciles exact-version global npm tools without querying the registry when
// the local installation is already healthy. Ownership is tracked separately
// from npm's inventory so removing a declaration prunes only tools installed
// by this mechanism, never unrelated global packages.
//
// Env vars:
//   DECLARED_TOOLS — JSON array of { name, version } exact-version declarations
//   STATE_FILE     — installer-owned convergence and managed-name state
//   LEGACY_SEED    — package names to treat as previously managed only when no
//                    state file exists (one-time migration cleanup)
//   NPM_COMMAND    — npm executable path (defaults to npm)
//   FORCE_REPAIR   — truthy value reinstalls declared tools

const fs = require("node:fs");
const { spawnSync } = require("node:child_process");
const { atomicWriteFileSync } = require("../../scripts/lib/managed-state.js");

const declaredTools = JSON.parse(process.env.DECLARED_TOOLS || "[]");
const stateFile = process.env.STATE_FILE;
const legacySeed = JSON.parse(process.env.LEGACY_SEED || "[]");
const npmCommand = process.env.NPM_COMMAND || "npm";
const forceRepair = /^(1|true|yes)$/i.test(process.env.FORCE_REPAIR || "");
const EXEC_TIMEOUT_MS = 60_000;
const EXACT_SEMVER = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;

function canonicalNames(names) {
  return [...new Set(names)].sort();
}

function validateDeclarations(tools) {
  if (!Array.isArray(tools)) throw new Error("DECLARED_TOOLS must be an array");
  const names = new Set();
  for (const tool of tools) {
    if (!tool || typeof tool.name !== "string" || typeof tool.version !== "string") {
      throw new Error("each declared npm tool must have string name and version fields");
    }
    if (!tool.name || !EXACT_SEMVER.test(tool.version)) {
      throw new Error("npm tool declarations must use exact semantic versions");
    }
    if (names.has(tool.name)) throw new Error("duplicate npm tool declaration: " + tool.name);
    names.add(tool.name);
  }
}

function readState(file) {
  if (!fs.existsSync(file)) {
    return { ok: true, converged: false, managed: new Set() };
  }
  try {
    const parsed = JSON.parse(fs.readFileSync(file, "utf8"));
    if (Array.isArray(parsed) && parsed.every((name) => typeof name === "string")) {
      return { ok: true, converged: false, managed: new Set(parsed) };
    }
    if (
      parsed &&
      typeof parsed.converged === "boolean" &&
      Array.isArray(parsed.managed) &&
      parsed.managed.every((name) => typeof name === "string")
    ) {
      return {
        ok: true,
        converged: parsed.converged,
        managed: new Set(parsed.managed),
      };
    }
    throw new Error("unrecognized npm tool state format");
  } catch (error) {
    console.error(
      "npmx: refusing to prune against unreadable state file " + stateFile + ": " + error.message
    );
    return { ok: false, converged: false, managed: new Set() };
  }
}

function writeState(managed, converged) {
  atomicWriteFileSync(stateFile, JSON.stringify({
    converged,
    managed: canonicalNames(managed),
  }) + "\n");
}

function readInventory() {
  const result = spawnSync(npmCommand, ["ls", "-g", "--depth=0", "--json"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    timeout: EXEC_TIMEOUT_MS,
  });
  try {
    const parsed = JSON.parse(result.stdout || "");
    const versions = new Map(
      Object.entries(parsed.dependencies || {}).map(([name, details]) => [name, details.version])
    );
    return {
      healthy: !result.error && result.status === 0 &&
        (!Array.isArray(parsed.problems) || parsed.problems.length === 0),
      usable: true,
      versions,
    };
  } catch (error) {
    console.error("npmx: failed to read global npm inventory: " + (result.error?.message || error.message));
    return { healthy: false, usable: false, versions: new Map() };
  }
}

function runNpm(args) {
  console.log("npmx: npm " + args.join(" "));
  const result = spawnSync(npmCommand, args, {
    stdio: "inherit",
    timeout: EXEC_TIMEOUT_MS,
  });
  return !result.error && result.status === 0;
}

function desiredStateIsHealthy(inventory, desired, staleManaged) {
  if (!inventory.healthy) return false;
  for (const [name, version] of desired) {
    if (inventory.versions.get(name) !== version) return false;
  }
  for (const name of staleManaged) {
    if (inventory.versions.has(name)) return false;
  }
  return true;
}

try {
  validateDeclarations(declaredTools);
} catch (error) {
  console.error("npmx: " + error.message);
  process.exit(1);
}

if (!fs.existsSync(stateFile) && legacySeed.length) {
  atomicWriteFileSync(stateFile, JSON.stringify(canonicalNames(legacySeed)) + "\n");
}

const state = readState(stateFile);
const desired = new Map(declaredTools.map((tool) => [tool.name, tool.version]));
const inventory = readInventory();
const managedAfterOperations = new Set(state.managed);
const staleManaged = new Set([...state.managed].filter((name) => !desired.has(name)));
const allDesiredAreManaged = [...desired.keys()].every((name) => state.managed.has(name));

if (
  !forceRepair && state.ok && state.converged && allDesiredAreManaged &&
  staleManaged.size === 0 && desiredStateIsHealthy(inventory, desired, staleManaged)
) {
  console.log("npmx: global npm tools already converged; skipping reconciliation");
  process.exit(0);
}

let operationsSucceeded = true;
for (const name of staleManaged) {
  if (inventory.usable && !inventory.versions.has(name)) {
    managedAfterOperations.delete(name);
    continue;
  }
  if (runNpm(["uninstall", "-g", name])) {
    managedAfterOperations.delete(name);
  } else {
    operationsSucceeded = false;
    console.error("npmx: failed to uninstall " + name);
  }
}

for (const [name, version] of desired) {
  const needsInstall = forceRepair || !state.ok || !state.managed.has(name) ||
    !inventory.healthy || inventory.versions.get(name) !== version;
  if (!needsInstall) continue;

  if (runNpm(["install", "-g", "--no-fund", "--no-audit", name + "@" + version])) {
    managedAfterOperations.add(name);
  } else {
    operationsSucceeded = false;
    console.error("npmx: failed to install " + name + "@" + version);
  }
}

const finalInventory = readInventory();
const converged = state.ok && operationsSucceeded &&
  desiredStateIsHealthy(finalInventory, desired, staleManaged);

if (state.ok) {
  writeState(managedAfterOperations, converged);
}
if (!converged) process.exitCode = 1;
