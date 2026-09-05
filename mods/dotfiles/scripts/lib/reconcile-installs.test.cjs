const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { reconcileInstalls } = require("./reconcile-installs.js");
function harness(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "reconcile-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const installed = new Set();
  const calls = [];
  const logs = [];
  const options = {
    stateFile: path.join(dir, "state.json"),
    desired: { a: { version: 1 }, b: { version: 1 } },
    observe: (id) => ({ status: installed.has(id) ? "healthy" : "missing" }),
    install: (id) => {
      calls.push("install " + id);
      installed.add(id);
    },
    remove: (id) => {
      calls.push("remove " + id);
      installed.delete(id);
    },
    log: (text) => logs.push(text),
  };
  return {
    options,
    calls,
    logs,
    installed,
    run: (extra) => reconcileInstalls({ ...options, ...extra }),
  };
}
test("healthy repeat changes neither installations nor state mtime", (t) => {
  const h = harness(t);
  assert.equal(h.run(), true);
  h.calls.length = 0;
  const before = fs.statSync(h.options.stateFile).mtimeMs;
  assert.equal(h.run(), true);
  assert.deepEqual(h.calls, []);
  assert.equal(fs.statSync(h.options.stateFile).mtimeMs, before);
});
test("one failed package does not reinstall successful siblings", (t) => {
  const h = harness(t);
  assert.equal(
    h.run({
      install: (id) => {
        h.calls.push("install " + id);
        if (id === "b") throw Error("offline");
        h.installed.add(id);
      },
    }),
    false,
  );
  h.calls.length = 0;
  assert.equal(h.run(), true);
  assert.deepEqual(h.calls, ["install b"]);
});
test("only changed declarations reinstall; only managed removals prune", (t) => {
  const h = harness(t);
  h.installed.add("manual");
  h.run();
  h.calls.length = 0;
  assert.equal(h.run({ desired: { a: { version: 2 } } }), true);
  assert.deepEqual(h.calls, ["remove b", "install a"]);
  assert.ok(h.installed.has("manual"));
});
test("inspection uncertainty never authorizes installation or removal", (t) => {
  const h = harness(t);
  h.run();
  h.calls.length = 0;
  assert.equal(
    h.run({
      desired: { a: { version: 1 } },
      observe: () => ({ status: "unknown", reason: "cannot read" }),
    }),
    false,
  );
  assert.deepEqual(h.calls, []);
  assert.ok(h.logs.some((line) => line.includes("cannot read")));
});
test("corrupt and unknown-schema state is retained without mutations", (t) => {
  const h = harness(t);
  for (const content of ["not json", '{"schema":99,"managed":[]}']) {
    fs.writeFileSync(h.options.stateFile, content);
    assert.equal(h.run(), false);
    assert.equal(fs.readFileSync(h.options.stateFile, "utf8"), content);
    assert.deepEqual(h.calls, []);
  }
});
test("legacy installs are adopted without reinstalling", (t) => {
  const h = harness(t);
  h.installed.add("a");
  h.installed.add("b");
  fs.writeFileSync(h.options.stateFile, '["a","b"]');
  assert.equal(h.run(), true);
  assert.deepEqual(h.calls, []);
});
test("failed repair stays pending even if old artifacts remain", (t) => {
  const h = harness(t);
  h.run();
  h.calls.length = 0;
  assert.equal(h.run({ force: true, install: () => false }), false);
  assert.equal(h.run(), true);
  assert.deepEqual(h.calls, ["install a", "install b"]);
});
test("failed removal is retried without reinstalling retained assets", (t) => {
  const h = harness(t);
  h.run();
  h.calls.length = 0;
  assert.equal(
    h.run({ desired: { a: { version: 1 } }, remove: () => false }),
    false,
  );
  assert.equal(h.run({ desired: { a: { version: 1 } } }), true);
  assert.deepEqual(h.calls, ["remove b"]);
});
test("post-install failure retains pending operations for retry", (t) => {
  const h = harness(t);
  assert.equal(h.run({ finish: () => false }), false);
  h.calls.length = 0;
  assert.equal(h.run(), true);
  assert.deepEqual(h.calls, ["install a", "install b"]);
});
test("post-removal failure retries finalization without forgetting ownership", (t) => {
  const h = harness(t);
  h.run();
  h.calls.length = 0;
  assert.equal(h.run({ desired: {}, finish: () => false }), false);
  assert.deepEqual(
    Object.keys(JSON.parse(fs.readFileSync(h.options.stateFile)).entries),
    ["a", "b"],
  );
  h.calls.length = 0;
  let finalized = false;
  assert.equal(
    h.run({
      desired: {},
      finish: () => {
        finalized = true;
      },
    }),
    true,
  );
  assert.equal(finalized, true);
  assert.deepEqual(h.calls, []);
  assert.deepEqual(
    JSON.parse(fs.readFileSync(h.options.stateFile)).entries,
    {},
  );
});
test("absent state never infers ownership from native inventory", (t) => {
  const h = harness(t);
  h.installed.add("a");
  h.installed.add("manual");
  assert.equal(h.run({ desired: {} }), true);
  assert.deepEqual(h.calls, []);
});
test("concurrent invocation fails closed without stealing a lock", (t) => {
  const h = harness(t);
  fs.mkdirSync(h.options.stateFile + ".lock");
  assert.equal(h.run(), false);
  assert.deepEqual(h.calls, []);
  assert.ok(fs.existsSync(h.options.stateFile + ".lock"));
});
