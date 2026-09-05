const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "npmx-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const log = path.join(dir, "calls");
  const state = path.join(dir, "state.json");
  const desired = [{ name: "@scope/tool", version: "1.2.3" }];
  const run = (tools = desired, extra = {}) =>
    spawnSync(process.execPath, [path.join(__dirname, "apply-npmx-tools.js")], {
      encoding: "utf8",
      env: {
        ...process.env,
        FORCE_REPAIR: "",
        STATE_FILE: state,
        DECLARED_TOOLS: JSON.stringify(tools),
        NPM_CONFIG_PREFIX: dir,
        NPM_COMMAND: path.join(__dirname, "test-fixtures/apply-npmx-tools/npm"),
        CALL_LOG: log,
        ...extra,
      },
    });
  return {
    dir,
    state,
    run,
    desired,
    calls: () =>
      fs.existsSync(log)
        ? fs.readFileSync(log, "utf8").trim().split("\n").filter(Boolean)
        : [],
    clear: () => fs.writeFileSync(log, ""),
  };
}
test("exact tools converge; repeat makes zero npm calls", (t) => {
  const h = fixture(t);
  assert.equal(h.run().status, 0);
  h.clear();
  assert.equal(h.run().status, 0);
  assert.deepEqual(h.calls(), []);
});
test("adding/changing one declaration installs only that tool", (t) => {
  const h = fixture(t);
  h.run();
  h.clear();
  assert.equal(
    h.run([...h.desired, { name: "other", version: "2.0.0" }]).status,
    0,
  );
  assert.deepEqual(h.calls(), ["install -g --no-fund --no-audit other@2.0.0"]);
});
test("failed sibling retries without reinstalling healthy tools", (t) => {
  const h = fixture(t);
  const tools = [...h.desired, { name: "other", version: "2.0.0" }];
  assert.equal(h.run(tools, { NPM_FAIL_INSTALL: "other" }).status, 1);
  h.clear();
  assert.equal(h.run(tools).status, 0);
  assert.deepEqual(h.calls(), ["install -g --no-fund --no-audit other@2.0.0"]);
});
test("legacy ownership is adopted without installers", (t) => {
  const h = fixture(t);
  h.run();
  fs.writeFileSync(
    h.state,
    JSON.stringify({ managed: ["@scope/tool"], converged: true }),
  );
  h.clear();
  assert.equal(h.run().status, 0);
  assert.deepEqual(h.calls(), []);
});
test("missing executable is repaired even with matching version", (t) => {
  const h = fixture(t);
  h.run();
  fs.unlinkSync(path.join(h.dir, "bin/tool"));
  h.clear();
  assert.equal(h.run().status, 0);
  assert.equal(h.calls().length, 1);
});
test("only owned removals are pruned and failed removals retry", (t) => {
  const h = fixture(t);
  h.run();
  h.clear();
  assert.equal(h.run([], { NPM_FAIL_UNINSTALL: "@scope/tool" }).status, 1);
  assert.equal(h.run([]).status, 0);
  assert.deepEqual(h.calls(), [
    "uninstall -g @scope/tool",
    "uninstall -g @scope/tool",
  ]);
});
test("malformed manifest is not an excuse to repeatedly run npm", (t) => {
  const h = fixture(t);
  h.run();
  fs.writeFileSync(
    path.join(h.dir, "lib/node_modules/@scope/tool/package.json"),
    "bad json",
  );
  h.clear();
  assert.equal(h.run().status, 1);
  assert.deepEqual(h.calls(), []);
  assert.equal(h.run(h.desired, { FORCE_REPAIR: "1" }).status, 0);
  assert.equal(h.calls().length, 1);
});
test("corrupt state is preserved without mutation", (t) => {
  const h = fixture(t);
  fs.writeFileSync(h.state, "bad json");
  assert.equal(h.run().status, 1);
  assert.deepEqual(h.calls(), []);
  assert.equal(fs.readFileSync(h.state, "utf8"), "bad json");
});
test("unrelated broken npm globals do not trigger repair", (t) => {
  const h = fixture(t);
  h.run();
  const dir = path.join(h.dir, "lib/node_modules/manual");
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, "package.json"), "bad json");
  h.clear();
  assert.equal(h.run().status, 0);
  assert.deepEqual(h.calls(), []);
});
test("force repair reinstalls and mutable versions are rejected", (t) => {
  const h = fixture(t);
  h.run();
  h.clear();
  assert.equal(h.run(h.desired, { FORCE_REPAIR: "1" }).status, 0);
  assert.equal(h.calls().length, 1);
  h.clear();
  assert.equal(h.run([{ name: "tool", version: "latest" }]).status, 1);
  assert.deepEqual(h.calls(), []);
});
