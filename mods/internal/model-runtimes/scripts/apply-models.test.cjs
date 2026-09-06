const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "apply-models.js");

// A fake backend: LIST reads models.txt, INSTALL appends an id, REMOVE deletes
// the matching line. Stands in for ollama/mlx-lm so the engine is exercised
// without either runtime installed.
function fakeAdapter(dir) {
  const store = path.join(dir, "models.txt");
  fs.writeFileSync(store, "");
  const list = path.join(dir, "list.sh");
  const install = path.join(dir, "install.sh");
  const remove = path.join(dir, "remove.sh");
  fs.writeFileSync(list, `#!/bin/sh\ncat ${store}\n`);
  fs.writeFileSync(install, `#!/bin/sh\necho "$1" >> ${store}\n`);
  fs.writeFileSync(remove, `#!/bin/sh\ngrep -vx "$1" ${store} > ${store}.tmp || true\nmv ${store}.tmp ${store}\n`);
  for (const f of [list, install, remove]) fs.chmodSync(f, 0o755);
  return { store, list: `sh ${list}`, install: `sh ${install}`, remove: `sh ${remove}` };
}

function run(dir, a, declared, extra = {}) {
  return execFileSync(process.execPath, [SCRIPT], {
    env: {
      ...process.env,
      BACKEND: "fake",
      DECLARED_MODELS: JSON.stringify(declared),
      STATE_FILE: path.join(dir, "state.json"),
      LIST_CMD: a.list,
      INSTALL_CMD: a.install,
      REMOVE_CMD: a.remove,
      ...extra,
    },
    encoding: "utf8",
  });
}

function installed(a) {
  return fs.readFileSync(a.store, "utf8").trim().split("\n").filter(Boolean).sort();
}

function mkTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "apply-models-test-"));
}

test("installs declared-missing models and records them in state", () => {
  const dir = mkTmpDir();
  const a = fakeAdapter(dir);
  run(dir, a, ["m1", "m2"]);
  assert.deepEqual(installed(a), ["m1", "m2"]);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(dir, "state.json"), "utf8")).sort(), ["m1", "m2"]);
});

test("does not reinstall an already-present declared model", () => {
  const dir = mkTmpDir();
  const a = fakeAdapter(dir);
  fs.writeFileSync(a.store, "m1\n"); // already installed out of band
  run(dir, a, ["m1"]);
  // Still exactly one m1 — no duplicate append from a needless install.
  assert.deepEqual(fs.readFileSync(a.store, "utf8").trim().split("\n").filter(Boolean), ["m1"]);
});

test("prunes only previously-managed models, leaving hand-installed ones", () => {
  const dir = mkTmpDir();
  const a = fakeAdapter(dir);
  run(dir, a, ["m1", "m2"]); // manages m1,m2
  fs.appendFileSync(a.store, "manual\n"); // a hand-pulled model appears
  run(dir, a, ["m1"]); // declare only m1
  // m2 pruned (tracked+undeclared); manual survives (never tracked); m1 stays.
  assert.deepEqual(installed(a), ["m1", "manual"]);
});

test("empty declared list prunes all tracked models but not untracked ones", () => {
  const dir = mkTmpDir();
  const a = fakeAdapter(dir);
  run(dir, a, ["m1", "m2"]);
  fs.appendFileSync(a.store, "manual\n");
  run(dir, a, []);
  assert.deepEqual(installed(a), ["manual"]);
});

test("a failed install warns but does not abort the batch or fail the run", () => {
  const dir = mkTmpDir();
  const a = fakeAdapter(dir);
  // install.sh that fails only for m1, succeeds otherwise.
  fs.writeFileSync(
    path.join(dir, "install.sh"),
    `#!/bin/sh\nif [ "$1" = "m1" ]; then exit 3; fi\necho "$1" >> ${a.store}\n`,
  );
  fs.chmodSync(path.join(dir, "install.sh"), 0o755);
  // Should not throw (exit 0) even though m1 fails; m2 still installed.
  run(dir, a, ["m1", "m2"]);
  assert.deepEqual(installed(a), ["m2"]);
});

test("an unreadable state file skips pruning and does not overwrite it", () => {
  const dir = mkTmpDir();
  const a = fakeAdapter(dir);
  const state = path.join(dir, "state.json");
  fs.writeFileSync(a.store, "m2\n"); // m2 present
  fs.writeFileSync(state, "not json {{{");
  const before = fs.readFileSync(state, "utf8");
  run(dir, a, ["m1"], { STATE_FILE: state });
  // m1 installed, but m2 NOT pruned (can't trust state), state left untouched.
  assert.deepEqual(installed(a), ["m1", "m2"]);
  assert.equal(fs.readFileSync(state, "utf8"), before, "corrupted state file untouched");
});
