// Runtime helpers shared by the native install adapters (npm, uv, Pi, Claude).
// Adapters own their domain logic; this module owns the two mechanics every
// adapter repeats: running a child process that must succeed, and reading the
// GLOBAL_TOOLS_FORCE_REPAIR / UPDATE style boolean env flags.
//
// Callers that must collect errors and keep going (status probes, update
// checks, the global-tools dispatcher) use spawnSync directly instead — this
// helper deliberately throws on the first failure.
const { spawnSync } = require("node:child_process");

// Run `command args`, throwing if it cannot start or exits non-zero. With
// `capture`, stdout is returned as a string; otherwise the child inherits this
// process's stdio. `cwd` defaults to the current directory; `timeout` caps the
// run at two minutes unless overridden.
function runProcess(command, args, { capture = false, cwd, timeout = 120_000 } = {}) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    stdio: capture ? ["ignore", "pipe", "pipe"] : "inherit",
    timeout,
  });
  if (result.error || result.status !== 0) {
    throw new Error(result.error?.message || `${command} exited ${result.status}`);
  }
  return result.stdout;
}

// Interpret a boolean-ish env flag ("1"/"true"/"yes", case-insensitive).
const truthy = (value) => /^(1|true|yes)$/i.test(value || "");

module.exports = { runProcess, truthy };
