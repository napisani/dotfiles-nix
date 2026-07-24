// Installs declared Pi packages via `pi install`, and removes any package
// this same mechanism previously installed but is no longer declared — true
// revocation, without touching packages installed by other means (Pi's own
// defaults, or manually via `pi install` outside of Nix): those never enter
// the tracked managed-set, so they're never pruned. (Confirmed via `pi list`
// that packages like npm:@ayulab/pi-rewind exist outside any Nix
// declaration — blindly pruning "anything not declared" would wrongly
// remove those.)
//
// Env vars:
//   DECLARED_PACKAGES — JSON array of package source strings (e.g. ["npm:pi-vim"])
//   STATE_FILE        — path to a small JSON file recording the previously-
//                        managed package set
//   LEGACY_SEED       — JSON array of package specs to seed into the state
//                        file only if it doesn't exist yet (one-time
//                        migration bootstrap — see mods/agents/pi.nix)

const fs = require("node:fs");
const { execFileSync } = require("node:child_process");
const { readManagedState, writeManagedState } = require("./lib/managed-state.js");

const declaredPackages = JSON.parse(process.env.DECLARED_PACKAGES || "[]");
const stateFile = process.env.STATE_FILE;
const legacySeed = JSON.parse(process.env.LEGACY_SEED || "[]");

const EXEC_TIMEOUT_MS = 60_000;

function run(args) {
  console.log("agents: pi " + args.join(" "));
  execFileSync("pi", args, { stdio: "inherit", timeout: EXEC_TIMEOUT_MS });
}

// First-run migration: if no state file exists yet, seed it with
// legacySeed so specs that used to be actively removed by an older,
// differently-tracked mechanism are still pruned once, instead of silently
// persisting forever just because they predate this tracking.
if (!fs.existsSync(stateFile) && legacySeed.length) {
  writeManagedState(stateFile, new Set(legacySeed));
}

const { ok: stateOk, managed: previouslyManaged } = readManagedState(stateFile);
const currentManaged = new Set(declaredPackages);

if (stateOk) {
  for (const pkg of previouslyManaged) {
    if (!currentManaged.has(pkg)) {
      try {
        run(["remove", pkg]);
        console.log("agents: removed undeclared Pi package '" + pkg + "'");
      } catch (e) {
        console.error("agents: WARNING: failed to remove undeclared Pi package '" + pkg + "': " + e.message);
      }
    }
  }
}

for (const pkg of declaredPackages) {
  try {
    run(["install", pkg]);
  } catch (e) {
    console.error("agents: WARNING: failed to install Pi package '" + pkg + "': " + e.message);
  }
}

if (stateOk) {
  writeManagedState(stateFile, currentManaged);
}
