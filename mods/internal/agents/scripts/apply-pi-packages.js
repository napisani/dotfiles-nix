// Pi adapter for per-asset native reconciliation. Only user-scoped inventory
// and declared artifacts determine routine health, not the entire npm tree.
// Env: DECLARED_PACKAGES, ALLOW_SCRIPTS, STATE_FILE, FORCE_REPAIR.
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { spawnSync } = require("node:child_process");
const { reconcileInstalls } = require(
  "../../scripts/lib/reconcile-installs.js",
);
const home = os.homedir();
const run = (command, args, capture = false, cwd = home) => {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    stdio: capture ? ["ignore", "pipe", "pipe"] : "inherit",
    timeout: 120_000,
  });
  if (result.error || result.status !== 0) {
    throw new Error(
      result.error?.message || `${command} exited ${result.status}`,
    );
  }
  return result.stdout;
};
let inventory;
function applyAllowScripts(allowScripts) {
  const file = path.join(home, ".pi/agent/npm/package.json");
  if (!fs.existsSync(file)) return;
  const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
  const desired = Object.fromEntries(allowScripts.map((name) => [name, true]));
  if (JSON.stringify(pkg.allowScripts || {}) === JSON.stringify(desired)) return;
  pkg.allowScripts = desired;
  const temporary = `${file}.tmp-${process.pid}`;
  fs.writeFileSync(temporary, `${JSON.stringify(pkg, null, 2)}\n`);
  fs.renameSync(temporary, file);
}
function inspect() {
  if (inventory) return inventory;
  const text = run("pi", ["list", "--no-approve"], true);
  inventory = new Map();
  let user = false;
  let current;
  for (const line of text.split("\n")) {
    if (/^\S/.test(line)) {
      user = line === "User packages:";
      current = null;
      continue;
    }
    if (!user) continue;
    const pkg = line.match(/^  (\S+)\s*$/);
    if (pkg) {
      current = pkg[1];
      inventory.set(current, null);
    } else if (current && /^    \S/.test(line)) {
      inventory.set(current, line.trim());
      current = null;
    }
  }
  if (
    text.trim() && !text.includes("User packages:") &&
    !/No packages installed/i.test(text)
  ) {
    inventory = null;
    throw new Error("unrecognized Pi inventory output");
  }
  return inventory;
}
try {
  const declared = JSON.parse(process.env.DECLARED_PACKAGES || "[]");
  const allowScripts = JSON.parse(process.env.ALLOW_SCRIPTS || "[]");
  if (
    !Array.isArray(declared) ||
    !declared.every((spec) =>
      typeof spec === "string" && /^(npm:|git:)/.test(spec)
    )
  ) throw new Error("invalid Pi declarations");
  if (new Set(declared).size !== declared.length) {
    throw new Error("duplicate Pi declarations");
  }
  if (
    !Array.isArray(allowScripts) ||
    !allowScripts.every((name) => typeof name === "string" && name.length > 0)
  ) throw new Error("invalid Pi npm script approvals");
  if (new Set(allowScripts).size !== allowScripts.length) {
    throw new Error("duplicate Pi npm script approvals");
  }
  const mode = process.env.RECONCILE_MODE || "apply";
  if (mode !== "status") applyAllowScripts(allowScripts);
  const desired = Object.fromEntries(
    declared.map((spec) => [spec, { source: spec }]),
  );
  const ok = reconcileInstalls({
    stateFile: process.env.STATE_FILE,
    mode,
    desired,
    force: /^(1|true|yes)$/i.test(process.env.FORCE_REPAIR || ""),
    observe(spec, desiredSpec) {
      const entries = inspect();
      if (!entries.has(spec)) return { status: "missing" };
      if (!desiredSpec) return { status: "healthy" };
      const artifact = entries.get(spec);
      if (!artifact || !fs.existsSync(artifact)) {
        return { status: "missing", reason: "missing Pi artifact" };
      }
      if (spec.startsWith("npm:")) {
        const file = path.join(artifact, "package.json");
        if (!fs.existsSync(file)) {
          return { status: "missing", reason: "missing package.json" };
        }
        const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
        const pinned = spec.match(/@([0-9]+\.[0-9]+\.[0-9]+(?:[-+][\w.-]+)?)$/)
          ?.[1];
        if (pinned && pkg.version !== pinned) {
          return {
            status: "missing",
            reason: "installed version differs from pin",
          };
        }
      }
      return { status: "healthy" };
    },
    install(spec) {
      const command = inspect().has(spec) ? "update" : "install";
      inventory = null;
      run("pi", [command, spec]);
    },
    remove(spec) {
      inventory = null;
      run("pi", ["remove", spec]);
    },
    finish() {
      const dir = path.join(home, ".pi/agent/npm");
      if (fs.existsSync(path.join(dir, "package.json"))) {
        run("npm", ["install", "--no-audit", "--no-fund"], false, dir);
      }
    },
  });
  if (!ok) process.exitCode = 1;
} catch (error) {
  console.error(`agents: Pi reconciliation failed: ${error.message}`);
  process.exitCode = 1;
}
