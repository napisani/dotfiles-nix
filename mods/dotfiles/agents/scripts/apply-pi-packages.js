// Reconciles declared Pi packages through `pi install`/`pi remove`.
//
// A successful state stamp records both the declaration fingerprint and the
// fact that the installed Pi package inventory and npm tree were healthy. An
// unchanged declaration can therefore skip the expensive installers, while a
// broken installation is repaired rather than frozen behind a matching hash.
//
// `pi install`/`pi remove` operate one package at a time and don't reconcile
// the shared ~/.pi/agent/npm tree as a whole. The npm install below runs only
// when package reconciliation is needed, so peer dependencies that become
// satisfiable after a remove/install are repaired without adding a network
// round trip to healthy activations.
//
// Env vars:
//   DECLARED_PACKAGES — JSON array of package source strings (e.g. ["npm:pi-vim"])
//   STATE_FILE        — path to the Pi package convergence state file
//   LEGACY_SEED       — JSON array of package specs to seed into the state
//                        file only if it doesn't exist yet
//   FORCE_REPAIR      — truthy value forces reconciliation even when healthy

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { execFileSync, spawnSync } = require("node:child_process");
const { atomicWriteFileSync } = require("../../scripts/lib/managed-state.js");

const declaredPackages = JSON.parse(process.env.DECLARED_PACKAGES || "[]");
const stateFile = process.env.STATE_FILE;
const legacySeed = JSON.parse(process.env.LEGACY_SEED || "[]");

const EXEC_TIMEOUT_MS = 60_000;

function run(args) {
  console.log("agents: pi " + args.join(" "));
  execFileSync("pi", args, { stdio: "inherit", timeout: EXEC_TIMEOUT_MS });
}

function canonicalPackages(packages) {
  return [...new Set(packages)].sort();
}

function declarationFingerprint(packages) {
  return crypto
    .createHash("sha256")
    .update(JSON.stringify(canonicalPackages(packages)))
    .digest("hex");
}

// Pi's state file used to be a plain array. Read that format as a legacy
// state so the first successful run upgrades it without losing ownership.
// Invalid state is deliberately not replaced: without knowing the old
// managed set, pruning could remove assets owned by somebody else.
function readPiState(file) {
  if (!fs.existsSync(file)) {
    return { ok: true, managed: new Set(), fingerprint: null, converged: false };
  }

  try {
    const parsed = JSON.parse(fs.readFileSync(file, "utf8"));
    if (Array.isArray(parsed) && parsed.every((pkg) => typeof pkg === "string")) {
      return { ok: true, managed: new Set(parsed), fingerprint: null, converged: false };
    }
    if (
      parsed &&
      typeof parsed.converged === "boolean" &&
      typeof parsed.declarationFingerprint === "string" &&
      Array.isArray(parsed.managed) &&
      parsed.managed.every((pkg) => typeof pkg === "string")
    ) {
      const managed = new Set(parsed.managed);
      if (parsed.converged && parsed.declarationFingerprint !== declarationFingerprint([...managed])) {
        throw new Error("declaration fingerprint does not match managed packages");
      }
      return {
        ok: true,
        managed,
        fingerprint: parsed.declarationFingerprint,
        converged: parsed.converged,
      };
    }
    throw new Error("unrecognized Pi state format");
  } catch (e) {
    console.error(
      "agents: refusing to prune against unreadable state file " + file + ": " + e.message +
      ". Skipping prune this run — fix or remove the file to resume tracking."
    );
    return { ok: false, managed: new Set(), fingerprint: null, converged: false };
  }
}

function writePiState(file, managed, fingerprint, converged) {
  atomicWriteFileSync(file, JSON.stringify({
    converged,
    declarationFingerprint: fingerprint,
    managed: canonicalPackages([...managed]),
  }) + "\n");
}

function capture(args) {
  const result = spawnSync("pi", args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    timeout: EXEC_TIMEOUT_MS,
  });
  if (result.error || result.status !== 0) {
    throw result.error || new Error("exited with status " + result.status);
  }
  return { stdout: result.stdout, stderr: result.stderr };
}

function piPackageInventory() {
  let result;
  try {
    result = capture(["list", "--no-approve"]);
  } catch (e) {
    console.error("agents: Pi package health check failed: " + e.message);
    return null;
  }
  if (result.stderr.trim()) {
    console.error("agents: Pi package health check reported warnings: " + result.stderr.trim());
    return null;
  }

  const entries = new Map();
  let currentPackage = null;
  for (const line of result.stdout.split("\n")) {
    const packageMatch = line.match(/^  (\S+)\s*$/);
    if (packageMatch) {
      currentPackage = packageMatch[1];
      entries.set(currentPackage, null);
      continue;
    }
    const artifactMatch = line.match(/^    (.+?)\s*$/);
    if (currentPackage && artifactMatch) {
      entries.set(currentPackage, artifactMatch[1]);
      currentPackage = null;
    }
  }
  return entries;
}

function installedPiPackagesAreHealthy() {
  const entries = piPackageInventory();
  if (!entries) return false;

  for (const pkg of declaredPackages) {
    const artifact = entries.get(pkg);
    if (!artifact || !fs.existsSync(artifact)) {
      return false;
    }
  }
  return true;
}

function npmTreeIsHealthy(piNpmDir) {
  if (!declaredPackages.length) return true;
  if (!fs.existsSync(path.join(piNpmDir, "package.json"))) return false;

  const result = spawnSync("npm", ["ls", "--prefix", piNpmDir, "--all", "--json"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    timeout: EXEC_TIMEOUT_MS,
  });
  if (result.error || result.status !== 0 || result.stderr.trim()) {
    console.error(
      "agents: Pi npm tree health check failed: " +
      (result.error ? result.error.message : result.stderr.trim() || "exited with status " + result.status)
    );
    return false;
  }

  try {
    const parsed = JSON.parse(result.stdout);
    return !Array.isArray(parsed.problems) || parsed.problems.length === 0;
  } catch (e) {
    console.error("agents: Pi npm tree health check returned invalid JSON: " + e.message);
    return false;
  }
}

function installedStateIsHealthy() {
  const piNpmDir = path.join(os.homedir(), ".pi", "agent", "npm");
  return installedPiPackagesAreHealthy() && npmTreeIsHealthy(piNpmDir);
}

function reconcileNpmTree() {
  const piNpmDir = path.join(os.homedir(), ".pi", "agent", "npm");
  if (!fs.existsSync(path.join(piNpmDir, "package.json"))) {
    return declaredPackages.length === 0;
  }

  try {
    console.log("agents: npm install (peer-dep reconcile) in " + piNpmDir);
    execFileSync("npm", ["install", "--no-audit", "--no-fund"], {
      cwd: piNpmDir,
      stdio: "inherit",
      timeout: EXEC_TIMEOUT_MS,
    });
    return true;
  } catch (e) {
    console.error("agents: WARNING: npm install reconcile failed in " + piNpmDir + ": " + e.message);
    return false;
  }
}

// First-run migration: if no state file exists yet, seed it with
// legacySeed so specs that used to be actively removed by an older,
// differently-tracked mechanism are still pruned once.
if (!fs.existsSync(stateFile) && legacySeed.length) {
  atomicWriteFileSync(stateFile, JSON.stringify(legacySeed) + "\n");
}

const state = readPiState(stateFile);
const currentManaged = new Set(declaredPackages);
const fingerprint = declarationFingerprint(declaredPackages);
const forceRepair = /^(1|true|yes)$/i.test(process.env.FORCE_REPAIR || "");

const canSkip = !forceRepair && state.ok && state.converged && state.fingerprint === fingerprint;
if (canSkip && installedStateIsHealthy()) {
  console.log("agents: Pi packages already converged; skipping reconciliation");
  process.exit(0);
}

let operationsSucceeded = true;
const managedAfterOperations = new Set(state.managed);
if (state.ok) {
  for (const pkg of state.managed) {
    if (!currentManaged.has(pkg)) {
      try {
        run(["remove", pkg]);
        managedAfterOperations.delete(pkg);
        console.log("agents: removed undeclared Pi package '" + pkg + "'");
      } catch (e) {
        operationsSucceeded = false;
        console.error("agents: WARNING: failed to remove undeclared Pi package '" + pkg + "': " + e.message);
      }
    }
  }
}

for (const pkg of declaredPackages) {
  try {
    run(["install", pkg]);
    managedAfterOperations.add(pkg);
  } catch (e) {
    operationsSucceeded = false;
    console.error("agents: WARNING: failed to install Pi package '" + pkg + "': " + e.message);
  }
}

const npmReconcileSucceeded = reconcileNpmTree();
const healthAfterReconcile = installedStateIsHealthy();
const converged = operationsSucceeded && npmReconcileSucceeded && healthAfterReconcile;

// Never replace unreadable state. For known state, record operation failures
// as unconverged while retaining every package still owned by this mechanism;
// that preserves failed removals for pruning and guarantees the next run
// retries instead of trusting an older success stamp.
if (state.ok) {
  writePiState(stateFile, converged ? currentManaged : managedAfterOperations, fingerprint, converged);
}
