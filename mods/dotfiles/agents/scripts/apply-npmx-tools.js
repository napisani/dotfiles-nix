// Exact-version npm adapter. Local package metadata and executable links are
// the health surface; unrelated global dependency problems cannot trigger installs.
// Env: DECLARED_TOOLS=[{name,version}], STATE_FILE,
// NPM_CONFIG_PREFIX (default ~/.local), NPM_COMMAND=npm, FORCE_REPAIR.
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { spawnSync } = require("node:child_process");
const { reconcileInstalls } = require(
  "../../scripts/lib/reconcile-installs.js",
);
const prefix = process.env.NPM_CONFIG_PREFIX ||
  path.join(os.homedir(), ".local");
const npm = process.env.NPM_COMMAND || "npm";
const exactVersion = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;
const validName = /^(?:@[a-z0-9._-]+\/)?[a-z0-9][a-z0-9._-]*$/i;
try {
  const declared = JSON.parse(process.env.DECLARED_TOOLS || "[]");
  if (!Array.isArray(declared)) {
    throw new Error("DECLARED_TOOLS must be an array");
  }
  const desired = {};
  for (const tool of declared) {
    if (
      !validName.test(tool?.name || "") ||
      !exactVersion.test(tool?.version || "")
    ) {
      throw new Error(
        "npm tools require package names and exact semantic versions",
      );
    }
    if (Object.hasOwn(desired, tool.name)) {
      throw new Error("duplicate npm tool");
    }
    desired[tool.name] = { version: tool.version };
  }
  const run = (args) => {
    const result = spawnSync(npm, args, { stdio: "inherit", timeout: 120_000 });
    if (result.error || result.status !== 0) {
      throw new Error(result.error?.message || `npm exited ${result.status}`);
    }
  };
  const ok = reconcileInstalls({
    stateFile: process.env.STATE_FILE,
    desired,
    force: /^(1|true|yes)$/i.test(process.env.FORCE_REPAIR || ""),
    observe(name, spec) {
      if (!validName.test(name)) throw new Error("invalid managed npm name");
      const file = path.join(prefix, "lib/node_modules", name, "package.json");
      if (!fs.existsSync(file)) return { status: "missing" };
      const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
      if (!spec) return { status: "healthy" };
      if (pkg.version !== spec.version) {
        return {
          status: "missing",
          reason: `expected ${spec.version}, found ${pkg.version}`,
        };
      }
      const bins = typeof pkg.bin === "string"
        ? { [name.split("/").pop()]: pkg.bin }
        : pkg.bin || {};
      for (const [bin, target] of Object.entries(bins)) {
        const executable = path.join(prefix, "bin", bin);
        try {
          fs.accessSync(executable, fs.constants.X_OK);
          if (
            fs.realpathSync(executable) !==
              fs.realpathSync(path.join(path.dirname(file), target))
          ) {
            return {
              status: "missing",
              reason: `wrong executable link: ${bin}`,
            };
          }
        } catch {
          return { status: "missing", reason: `missing executable: ${bin}` };
        }
      }
      return { status: "healthy" };
    },
    install: (name, spec) =>
      run([
        "install",
        "-g",
        "--no-fund",
        "--no-audit",
        `${name}@${spec.version}`,
      ]),
    remove: (name) => run(["uninstall", "-g", name]),
  });
  if (!ok) process.exitCode = 1;
} catch (error) {
  console.error(`npmx: ${error.message}`);
  process.exitCode = 1;
}
