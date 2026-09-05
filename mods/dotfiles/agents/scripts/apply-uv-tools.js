// uv adapter: registry tools, editable toolbox projects, and the vocal venv.
// Env: DECLARED_TOOLS={name:{package,with?,extras?}}, TOOLBOX, VOCAL_VENV,
// STATE_FILE, UV_COMMAND, PYTHON_COMMAND, FORCE_REPAIR. All probes are offline.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { spawnSync } = require("node:child_process");
const { reconcileInstalls } = require(
  "../../scripts/lib/reconcile-installs.js",
);
const uv = process.env.UV_COMMAND || "uv";
const python = process.env.PYTHON_COMMAND || "python3";
const normalize = (name) => name.toLowerCase().replace(/[-_.]+/g, "-");
const packageName = (requirement) =>
  normalize(requirement.match(/^[a-z0-9_.-]+/i)?.[0] || "");
function execute(command, args, capture = false) {
  const result = spawnSync(command, args, {
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
}
const readToml = (file) =>
  JSON.parse(
    execute(python, [
      path.join(__dirname, "../../scripts/lib/toml-json.py"),
      file,
    ], true),
  );
let inventory;
function tools() {
  if (inventory) return inventory;
  const output = execute(
    uv,
    ["--offline", "tool", "list", "--show-paths"],
    true,
  );
  const result = new Map();
  for (const line of output.split("\n").filter(Boolean)) {
    if (line.startsWith("- ")) continue;
    const match = line.match(/^([\w.-]+) v\S+ \((.+)\)$/);
    if (!match) throw new Error("unrecognized uv tool inventory");
    result.set(normalize(match[1]), match[2]);
  }
  inventory = result;
  return result;
}
const pipInventory = (pythonPath) =>
  JSON.parse(
    execute(uv, [
      "--offline",
      "pip",
      "list",
      "--python",
      pythonPath,
      "--format",
      "json",
    ], true),
  );
try {
  const declared = JSON.parse(process.env.DECLARED_TOOLS || "{}");
  const desired = {};
  for (const [name, spec] of Object.entries(declared)) {
    if (
      !/^[a-z0-9][a-z0-9_.-]*$/i.test(name) ||
      typeof spec.package !== "string" ||
      packageName(spec.package) !== normalize(name)
    ) throw new Error("invalid uv declaration");
    desired[normalize(name)] = { ...spec, kind: "tool" };
  }
  const toolbox = process.env.TOOLBOX;
  if (toolbox && fs.existsSync(toolbox)) {
    for (const name of fs.readdirSync(toolbox)) {
      const dir = path.join(toolbox, name);
      const projectFile = path.join(dir, "pyproject.toml");
      if (!fs.existsSync(projectFile)) continue;
      const project = readToml(projectFile).project;
      if (!project?.name) {
        throw new Error(`missing project.name in ${projectFile}`);
      }
      const id = normalize(project.name);
      if (Object.hasOwn(desired, id)) {
        throw new Error(`duplicate uv tool ${id}`);
      }
      const metadata = ["pyproject.toml", "uv.lock"].map((file) =>
        fs.existsSync(path.join(dir, file))
          ? fs.readFileSync(path.join(dir, file), "utf8")
          : null
      );
      desired[id] = {
        kind: "tool",
        package: id,
        editable: fs.realpathSync(dir),
        metadata: crypto.createHash("sha256").update(JSON.stringify(metadata))
          .digest("hex"),
      };
    }
  }
  if (process.env.VOCAL_VENV) {
    desired["venv:vocal"] = {
      kind: "venv",
      path: process.env.VOCAL_VENV,
      packages: ["requests"],
    };
  }
  const force = /^(1|true|yes)$/i.test(process.env.FORCE_REPAIR || "");
  const ok = reconcileInstalls({
    stateFile: process.env.STATE_FILE,
    desired,
    force,
    observe(id, spec, previousSpec) {
      if (id === "venv:vocal") {
        const venv = spec || previousSpec;
        if (!venv || venv.kind !== "venv") {
          throw new Error("missing managed venv specification");
        }
        const interpreter = path.join(venv.path, "bin/python");
        if (!fs.existsSync(interpreter)) {
          return { status: "missing", reason: "missing vocal interpreter" };
        }
        const installed = pipInventory(interpreter);
        const present = (name) =>
          installed.some((pkg) => normalize(pkg.name) === name);
        return {
          status:
            (spec ? venv.packages.every(present) : venv.packages.some(present))
              ? "healthy"
              : "missing",
        };
      }
      const dir = tools().get(id);
      if (!dir) return { status: "missing" };
      if (!spec) return { status: "healthy" };
      const interpreter = path.join(dir, "bin/python");
      const receiptFile = path.join(dir, "uv-receipt.toml");
      if (!fs.existsSync(interpreter) || !fs.existsSync(receiptFile)) {
        return { status: "missing", reason: "missing uv environment/receipt" };
      }
      const receipt = readToml(receiptFile).tool;
      const requirement = receipt?.requirements?.find((item) =>
        normalize(item.name) === id
      );
      if (!requirement) {
        return { status: "missing", reason: "missing uv requirement" };
      }
      if (
        spec.editable &&
        (!requirement.editable || !fs.existsSync(requirement.editable) ||
          fs.realpathSync(requirement.editable) !== spec.editable)
      ) return { status: "missing", reason: "editable source differs" };
      if (
        (spec.extras || []).some((extra) =>
          !requirement.extras?.includes(extra)
        )
      ) return { status: "missing", reason: "missing requested extras" };
      for (const bin of receipt.entrypoints || []) {
        try {
          fs.accessSync(bin["install-path"], fs.constants.X_OK);
        } catch {
          return {
            status: "missing",
            reason: `missing uv executable ${bin.name}`,
          };
        }
      }
      const installed = pipInventory(interpreter);
      const required = [spec.package, ...(spec.with || [])];
      const healthy = required.every((req) =>
        installed.some((pkg) =>
          normalize(pkg.name) === packageName(req) &&
          (!req.includes("==") || pkg.version === req.split("==")[1])
        )
      );
      return {
        status: healthy ? "healthy" : "missing",
        reason: healthy ? undefined : "missing uv requirement/version",
      };
    },
    install(id, spec) {
      inventory = null;
      if (spec.kind === "venv") {
        const interpreter = path.join(spec.path, "bin/python");
        if (!fs.existsSync(interpreter)) {
          execute(uv, ["venv", "--python", python, spec.path]);
        }
        execute(uv, [
          "pip",
          "install",
          "--python",
          interpreter,
          ...(force
            ? spec.packages.flatMap((name) => ["--reinstall-package", name])
            : []),
          ...spec.packages,
        ]);
      } else {
        const args = ["tool", "install", "--force"];
        if (force) args.push("--reinstall");
        else if (spec.editable) args.push("--reinstall-package", id);
        for (const dependency of spec.with || []) {
          args.push("--with", dependency);
        }
        if (spec.editable) args.push("--editable", spec.editable);
        else args.push(spec.package);
        execute(uv, args);
      }
    },
    remove(id, spec) {
      inventory = null;
      if (spec?.kind === "venv") {
        execute(uv, [
          "pip",
          "uninstall",
          "--python",
          path.join(spec.path, "bin/python"),
          ...spec.packages,
        ]);
      } else execute(uv, ["tool", "uninstall", id]);
    },
  });
  if (!ok) process.exitCode = 1;
} catch (error) {
  console.error(`uvx: ${error.message}`);
  process.exitCode = 1;
}
