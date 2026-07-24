// Installs/refreshes declared Claude Code plugins via `claude plugin`, and
// uninstalls any plugin this same mechanism previously installed but is no
// longer declared — true revocation, without ever touching plugins Claude
// itself or the user installed outside of Nix (e.g. bundled/official ones):
// those never appear in the tracked managed-set, so they're never pruned.
//
// To avoid every activation depending on marketplace network availability
// for plugins that haven't changed, only *newly*-declared plugins get the
// full uninstall-then-install refresh cycle; plugins already tracked as
// managed from a prior run just get `install` (which is expected to update
// in place if the CLI supports it), skipping the destructive uninstall step
// for the common steady-state case.
//
// Env vars:
//   MARKETPLACE      — single marketplace source string to register (e.g.
//                      "loancrate/org-claude-skills#workmux"), or empty/unset
//   DECLARED_PLUGINS — JSON array of "<plugin>@<marketplaceName>" strings,
//                      this run's full declared set
//   STATE_FILE       — path to a small JSON file recording the previously-
//                      managed plugin spec set

const { execFileSync } = require("node:child_process");
const { readManagedState, writeManagedState } = require("./lib/managed-state.js");

const marketplace = process.env.MARKETPLACE || "";
const declaredPlugins = JSON.parse(process.env.DECLARED_PLUGINS || "[]");
const stateFile = process.env.STATE_FILE;

const EXEC_TIMEOUT_MS = 60_000;

function run(args) {
  console.log("agents: claude " + args.join(" "));
  execFileSync("claude", args, { stdio: "inherit", timeout: EXEC_TIMEOUT_MS });
}

const { ok: stateOk, managed: previouslyManaged } = readManagedState(stateFile);
const currentManaged = new Set(declaredPlugins);

if (marketplace) {
  try {
    run(["plugin", "marketplace", "add", marketplace, "--scope", "user"]);
  } catch (e) {
    console.error("agents: WARNING: failed to add marketplace '" + marketplace + "': " + e.message);
  }
}

// Prune: uninstall anything WE previously installed but is no longer
// declared. Skipped entirely if the state file was unreadable — see
// readManagedState in lib/managed-state.js.
if (stateOk) {
  for (const pluginSpec of previouslyManaged) {
    if (!currentManaged.has(pluginSpec)) {
      try {
        run(["plugin", "uninstall", pluginSpec, "--scope", "user"]);
        console.log("agents: uninstalled undeclared plugin '" + pluginSpec + "'");
      } catch (e) {
        console.error("agents: WARNING: failed to uninstall undeclared plugin '" + pluginSpec + "': " + e.message);
      }
    }
  }
}

// Install/refresh: plugins new to management get a clean uninstall-then-
// install so any stale local state is cleared; plugins already tracked as
// managed just get `install`, so a steady-state activation with nothing
// changed doesn't force a network round trip and a destructive uninstall
// for every declared plugin, every time.
for (const pluginSpec of declaredPlugins) {
  const isNew = !previouslyManaged.has(pluginSpec);
  if (isNew) {
    try {
      run(["plugin", "uninstall", pluginSpec, "--scope", "user"]);
    } catch (e) {
      // Not previously installed — fine, proceed to install.
    }
  }
  try {
    run(["plugin", "install", pluginSpec, "--scope", "user"]);
  } catch (e) {
    console.error("agents: WARNING: failed to install plugin '" + pluginSpec + "': " + e.message);
  }
}

if (stateOk) {
  writeManagedState(stateFile, currentManaged);
}
