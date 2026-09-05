const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-reconcile-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const npmDir = path.join(dir, ".pi/agent/npm");
  fs.mkdirSync(npmDir, { recursive: true });
  fs.writeFileSync(path.join(npmDir, "package.json"), "{}");
  const log = path.join(dir, "calls");
  const npmLog = path.join(dir, "npm-calls");
  const state = path.join(dir, "state.json");
  const run = (packages = ["npm:pi-vim"], extra = {}) =>
    spawnSync(
      process.execPath,
      [path.join(__dirname, "apply-pi-packages.js")],
      {
        encoding: "utf8",
        env: {
          ...process.env,
          HOME: dir,
          FORCE_REPAIR: "",
          PATH: `${
            path.join(__dirname, "test-fixtures/apply-pi-packages")
          }:${process.env.PATH}`,
          STATE_FILE: state,
          DECLARED_PACKAGES: JSON.stringify(packages),
          CALL_LOG: log,
          NPM_CALL_LOG: npmLog,
          PI_INSTALL_STATE: path.join(dir, "installed"),
          ...extra,
        },
      },
    );
  const calls = (file) =>
    fs.existsSync(file)
      ? fs.readFileSync(file, "utf8").trim().split("\n").filter(Boolean)
      : [];
  return {
    dir,
    npmDir,
    state,
    run,
    calls: () => calls(log),
    npmCalls: () => calls(npmLog),
    clear: () => {
      fs.writeFileSync(log, "");
      fs.writeFileSync(npmLog, "");
    },
  };
}
test("unchanged healthy Pi runs perform no installs or npm calls", (t) => {
  const h = fixture(t);
  const first = h.run();
  assert.equal(first.status, 0, first.stderr);
  h.clear();
  assert.equal(h.run().status, 0);
  assert.deepEqual(h.calls(), ["list --no-approve"]);
  assert.deepEqual(h.npmCalls(), []);
});
test("one failed package does not reinstall successful siblings on retry", (t) => {
  const h = fixture(t);
  const declared = ["npm:pi-vim", "npm:other"];
  assert.equal(h.run(declared, { PI_FAIL_INSTALL: "npm:other" }).status, 1);
  h.clear();
  assert.equal(h.run(declared).status, 0);
  assert.deepEqual(h.calls().filter((c) => c.startsWith("install")), [
    "install npm:other",
  ]);
});
test("benign warnings and unrelated npm tree problems do not trigger installs", (t) => {
  const h = fixture(t);
  h.run();
  h.clear();
  assert.equal(
    h.run(undefined, {
      PI_LIST_WARNING: "update available",
      NPM_HEALTH: "invalid",
    }).status,
    0,
  );
  assert.deepEqual(h.calls(), ["list --no-approve"]);
  assert.deepEqual(h.npmCalls(), []);
});
test("unknown inventory refuses mutations", (t) => {
  const h = fixture(t);
  h.run();
  h.clear();
  assert.equal(h.run(undefined, { PI_LIST_INVALID: "1" }).status, 1);
  assert.ok(h.calls().every((c) => c === "list --no-approve"));
  assert.deepEqual(h.npmCalls(), []);
});
test("missing artifact repairs only that package", (t) => {
  const h = fixture(t);
  const declared = ["npm:pi-vim", "npm:other"];
  h.run(declared);
  fs.rmSync(path.join(h.npmDir, "node_modules/other"), { recursive: true });
  h.clear();
  assert.equal(h.run(declared).status, 0);
  assert.deepEqual(h.calls().filter((c) => c.startsWith("install")), [
    "install npm:other",
  ]);
});
test("exact version changes remove old spec and install new one", (t) => {
  const h = fixture(t);
  h.run(["npm:pi-vim@1.0.0"]);
  h.clear();
  assert.equal(h.run(["npm:pi-vim@2.0.0"]).status, 0);
  assert.ok(h.calls().includes("remove npm:pi-vim@1.0.0"));
  assert.ok(h.calls().includes("install npm:pi-vim@2.0.0"));
});
test("legacy array migrates without blindly reinstalling healthy packages", (t) => {
  const h = fixture(t);
  h.run();
  fs.writeFileSync(h.state, '["npm:pi-vim"]');
  h.clear();
  assert.equal(h.run().status, 0);
  assert.deepEqual(h.calls(), ["list --no-approve"]);
  assert.deepEqual(h.npmCalls(), []);
});
test("failed removal retains ownership and is retried", (t) => {
  const h = fixture(t);
  h.run();
  h.clear();
  assert.equal(h.run([], { PI_FAIL_REMOVE: "npm:pi-vim" }).status, 1);
  assert.equal(h.run([]).status, 0);
  assert.equal(h.calls().filter((c) => c === "remove npm:pi-vim").length, 2);
});
test("failed batch npm reconciliation is retried", (t) => {
  const h = fixture(t);
  assert.equal(h.run(undefined, { NPM_FAIL_INSTALL: "1" }).status, 1);
  h.clear();
  assert.equal(h.run().status, 0);
  assert.ok(h.calls().includes("install npm:pi-vim"));
});
test("corrupt state never authorizes mutations", (t) => {
  const h = fixture(t);
  fs.writeFileSync(h.state, "not-json");
  assert.equal(h.run().status, 1);
  assert.deepEqual(h.calls(), []);
  assert.equal(fs.readFileSync(h.state, "utf8"), "not-json");
});
test("explicit repair reconciles healthy packages", (t) => {
  const h = fixture(t);
  h.run();
  h.clear();
  assert.equal(h.run(undefined, { FORCE_REPAIR: "1" }).status, 0);
  assert.ok(h.calls().includes("install npm:pi-vim"));
});
