const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");
function harness(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "global-tools-cli-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const command = path.join(__dirname, "test-fixtures/global-tools/component");
  const source = path.join(dir, "source"), target = path.join(dir, "target");
  fs.writeFileSync(source, "managed");
  fs.symlinkSync(source, target);
  const manifest = path.join(dir, "manifest.json"),
    log = path.join(dir, "calls");
  fs.writeFileSync(
    manifest,
    JSON.stringify({
      operations: [{ name: "first", command, checkUpdates: command }, {
        name: "second",
        command,
        canUpdate: true,
      }],
      files: [{ target, source }],
    }),
  );
  return {
    target,
    log,
    calls: () =>
      fs.existsSync(log)
        ? fs.readFileSync(log, "utf8").trim().split("\n").map((line) =>
          JSON.parse(line)
        )
        : [],
    run: (args, env = {}) =>
      spawnSync(process.execPath, [
        path.join(__dirname, "global-tools.js"),
        manifest,
        ...args,
      ], { encoding: "utf8", env: { ...process.env, CALL_LOG: log, ...env } }),
  };
}
test("help and usage identify global-tools without running components", (t) => {
  const h = harness(t);
  const help = h.run(["--help"]);
  assert.equal(help.status, 0);
  assert.match(
    help.stdout,
    /^global-tools \{status\|apply\|repair\|check-updates\|update\} \[component\]/,
  );
  const invalid = h.run(["invalid"]);
  assert.equal(invalid.status, 1);
  assert.match(invalid.stderr, /^global-tools /);
  assert.deepEqual(h.calls(), []);
});
test("status clears mutation flags and checks Nix links without repairing them", (t) => {
  const h = harness(t);
  assert.equal(
    h.run(["status"], { GLOBAL_TOOLS_FORCE_REPAIR: "1", GLOBAL_TOOLS_UPDATE: "1" }).status,
    0,
  );
  assert.deepEqual(
    h.calls(),
    Array(2).fill({ mode: "status", repair: "", update: "" }),
  );
  fs.unlinkSync(h.target);
  assert.equal(h.run(["repair", "files"]).status, 1);
  assert.equal(fs.existsSync(h.target), false);
  assert.equal(h.calls().length, 2);
});
test("repair continues after a component failure and fails overall", (t) => {
  const h = harness(t);
  assert.equal(h.run(["repair"], { FAIL_FIRST_CALL: "1" }).status, 1);
  assert.deepEqual(
    h.calls(),
    Array(2).fill({ mode: "apply", repair: "1", update: "" }),
  );
});
test("updates dispatch only supported native operations; bad targets never run", (t) => {
  const h = harness(t);
  assert.equal(h.run(["update"]).status, 0);
  assert.deepEqual(h.calls(), [{ mode: "apply", repair: "", update: "1" }]);
  assert.equal(h.run(["check-updates"]).status, 0);
  assert.equal(h.calls().length, 2);
  assert.equal(h.run(["repair", "typo"]).status, 1);
  assert.equal(h.run(["update", "first"]).status, 1);
  assert.equal(h.calls().length, 2);
});
