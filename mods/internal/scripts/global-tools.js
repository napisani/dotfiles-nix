// Operational dispatcher only. Adapters retain their native commands/state;
// this manifest is bound to the installed Home Manager generation.
const fs = require("node:fs");
const { spawnSync } = require("node:child_process");

const MODES = ["status", "apply", "repair", "check-updates", "update"];
const USAGE =
  "global-tools {status|apply|repair|check-updates|update} [component]";

function main() {
  const [manifestPath, mode = "status", component, ...extra] = process.argv
    .slice(2);
  if (mode === "--help" || mode === "help") {
    console.log(USAGE);
    return 0;
  }
  if (extra.length || !MODES.includes(mode)) throw new Error(USAGE);

  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  validateComponent(manifest, component);

  let failed = false;
  if (
    ["status", "apply", "repair"].includes(mode) &&
    (!component || component === "files")
  ) {
    failed = checkManagedFiles(manifest) || failed;
  }
  failed = runOperations(manifest, mode, component) || failed;

  // Files are Nix-owned links: there is nothing for this CLI to update.
  if (component === "files" && ["update", "check-updates"].includes(mode)) {
    throw new Error("files: update Nix inputs/declarations, then switch");
  }
  return failed ? 1 : 0;
}

function validateComponent(manifest, component) {
  if (
    component && component !== "files" &&
    !manifest.operations.some((op) => op.name === component)
  ) {
    throw new Error(
      `unknown component ${component}; choose files, ${
        manifest.operations.map((op) => op.name).join(", ")
      }`,
    );
  }
}

// Report (never repair) the Nix-owned managed links; drift is a failure.
function checkManagedFiles(manifest) {
  let drift = 0;
  for (const file of manifest.files) {
    try {
      if (fs.realpathSync(file.target) === fs.realpathSync(file.source)) {
        continue;
      }
    } catch {}
    console.error(`files: missing or different managed link: ${file.target}`);
    drift++;
  }
  console.log(
    `files: ${
      manifest.files.length - drift
    }/${manifest.files.length} managed links healthy`,
  );
  if (drift) {
    console.error(
      "files: restore Home Manager-owned assets with a switch; global-tools never relinks them.",
    );
  }
  return drift > 0;
}

// Pick the command a given mode runs for an operation, or null if unsupported.
function commandFor(op, mode) {
  if (mode === "check-updates") return op.checkUpdates;
  if (mode === "update") return op.canUpdate ? op.command : null;
  return op.command;
}

function runOperations(manifest, mode, component) {
  let failed = false;
  for (const op of manifest.operations) {
    if (component && component !== op.name) continue;
    const command = commandFor(op, mode);
    if (!command) {
      if (component) throw new Error(`${op.name} does not support ${mode}`);
      continue;
    }
    console.log(`${op.name}: ${mode}`);
    const result = spawnSync(command, [], {
      stdio: "inherit",
      env: {
        ...process.env,
        RECONCILE_MODE: mode === "status" ? "status" : "apply",
        GLOBAL_TOOLS_FORCE_REPAIR: mode === "repair" ? "1" : "",
        GLOBAL_TOOLS_UPDATE: mode === "update" ? "1" : "",
      },
    });
    if (result.error || result.status !== 0) {
      failed = true;
      console.error(
        `${op.name}: ${result.error?.message || `exited ${result.status}`}`,
      );
    }
  }
  return failed;
}

try {
  process.exitCode = main();
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
