// Claude owns plugin inventory and marketplace registration. The shared engine
// owns progress, legacy-state adoption, retry, status, and managed-only pruning.
// Marketplace sources are inputs to plugin installation, not an excuse to
// uninstall a shared marketplace and its user-managed plugins.
const fs = require("node:fs");
const { spawnSync } = require("node:child_process");
const { reconcileInstalls } = require(
  "../../scripts/lib/reconcile-installs.js",
);
const truthy = (value) => /^(1|true|yes)$/i.test(value || "");
function run(args, capture = false) {
  const result = spawnSync("claude", args, {
    encoding: "utf8",
    stdio: capture ? ["ignore", "pipe", "pipe"] : "inherit",
    timeout: 60_000,
  });
  if (result.error || result.status !== 0) {
    throw new Error(
      result.error?.message ||
        `claude ${args.slice(0, 2).join(" ")} exited ${result.status}`,
    );
  }
  return result.stdout;
}
let inventory;
function plugins() {
  if (!inventory) {
    const entries = JSON.parse(run(["plugin", "list", "--json"], true));
    if (
      !Array.isArray(entries) ||
      !entries.every((entry) =>
        typeof entry?.id === "string" &&
        ["user", "project", "local"].includes(entry.scope)
      )
    ) throw new Error("invalid Claude plugin inventory");
    inventory = new Map(
      entries.filter((entry) => entry.scope === "user").map(
        (entry) => [entry.id, entry],
      ),
    );
  }
  return inventory;
}
try {
  const marketplaces = JSON.parse(process.env.MARKETPLACES || "[]");
  const declared = JSON.parse(process.env.DECLARED_PLUGINS || "[]");
  for (const values of [marketplaces, declared]) {
    if (
      !Array.isArray(values) || !values.every((value) =>
        typeof value === "string" && value.length > 0 && !value.startsWith("-")
      ) || new Set(values).size !== values.length
    ) {
      throw new Error("invalid Claude declarations");
    }
  }
  const repair = truthy(process.env.FORCE_REPAIR);
  const update = truthy(process.env.UPDATE);
  let registered = false;
  function prepareMarketplaces() {
    if (registered) return;
    for (const source of marketplaces) {
      run(["plugin", "marketplace", "add", source, "--scope", "user"]);
    }
    if (update && marketplaces.length) {
      const sources = JSON.parse(
        run(["plugin", "marketplace", "list", "--json"], true),
      );
      if (!Array.isArray(sources)) {
        throw new Error("invalid marketplace inventory");
      }
      for (const source of marketplaces) {
        const entry = sources.find((entry) =>
          [entry.repo, entry.url, entry.path].includes(source)
        );
        if (!entry?.name) {
          throw new Error(`cannot resolve declared marketplace ${source}`);
        }
        run(["plugin", "marketplace", "update", entry.name]);
      }
    }
    registered = true;
  }
  const ok = reconcileInstalls({
    stateFile: process.env.STATE_FILE,
    mode: process.env.RECONCILE_MODE || "apply",
    desired: Object.fromEntries(
      declared.map((id) => [id, { marketplaces: [...marketplaces].sort() }]),
    ),
    force: repair || update,
    observe(id, spec) {
      if (id.startsWith("-")) throw new Error("invalid plugin ID");
      const entry = plugins().get(id);
      if (!entry) return { status: "missing" };
      if (spec && entry.installPath && !fs.existsSync(entry.installPath)) {
        return { status: "missing", reason: "missing plugin artifact" };
      }
      return { status: "healthy" };
    },
    install(id) {
      prepareMarketplaces();
      let present = false;
      try {
        present = plugins().has(id);
      } catch (error) {
        // Explicit repair may reinstall a declared uncertain asset, but must
        // not infer that an unknown native installation may be uninstalled.
        if (!repair && !update) throw error;
      }
      inventory = null;
      if (repair && present) {
        run(["plugin", "uninstall", id, "--scope", "user"]);
      }
      if (update && present && !repair) {
        run(["plugin", "update", id, "--scope", "user", "--yes"]);
      } else run(["plugin", "install", id, "--scope", "user"]);
    },
    remove(id) {
      inventory = null;
      run(["plugin", "uninstall", id, "--scope", "user"]);
    },
  });
  if (!ok) process.exitCode = 1;
} catch (error) {
  console.error(
    `agents: Claude plugin reconciliation failed: ${error.message}`,
  );
  process.exitCode = 1;
}
