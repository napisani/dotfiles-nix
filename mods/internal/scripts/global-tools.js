// Operational dispatcher only. Adapters retain their native commands/state;
// this manifest is bound to the installed Home Manager generation.
const fs = require("node:fs");
const { spawnSync } = require("node:child_process");
const [manifestPath, mode = "status", component, ...extra] = process.argv.slice(
  2,
);
const usage =
  "global-tools {status|apply|repair|check-updates|update} [component]";
if (mode === "--help" || mode === "help") {
  console.log(usage);
  process.exit(0);
}
try {
  if (
    extra.length ||
    !["status", "apply", "repair", "check-updates", "update"].includes(mode)
  ) throw new Error(usage);
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
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
  let failed = false;
  if (
    ["status", "apply", "repair"].includes(mode) &&
    (!component || component === "files")
  ) {
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
      failed = true;
    }
  }
  for (const op of manifest.operations) {
    if (component && component !== op.name) continue;
    const command = mode === "check-updates"
      ? op.checkUpdates
      : mode === "update"
      ? (op.canUpdate ? op.command : null)
      : op.command;
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
  if (component === "files" && ["update", "check-updates"].includes(mode)) {
    throw new Error("files: update Nix inputs/declarations, then switch");
  }
  if (failed) process.exitCode = 1;
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
