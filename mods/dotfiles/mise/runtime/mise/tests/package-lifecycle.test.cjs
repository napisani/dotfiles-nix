const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawn, spawnSync } = require("node:child_process");
const { environment, mise } = require("./test-fixtures/environment.cjs");
const { setTimeout: delay } = require("node:timers/promises");
const test = require("node:test");

const fixtureDir = path.join(__dirname, "test-fixtures/package-lifecycle");

function fixture(t) {
  const root = fs.realpathSync(
    fs.mkdtempSync(path.join(os.tmpdir(), "mise-lifecycle-")),
  );
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const home = path.join(root, "home");
  const work = path.join(root, "work");
  const config = path.join(root, "config/mise/config.toml");
  const data = path.join(root, "data/mise");
  const nativeState = path.join(root, "native.json");
  for (
    const dir of [home, work, path.dirname(config), path.join(data, "plugins")]
  ) {
    fs.mkdirSync(dir, { recursive: true });
  }
  fs.symlinkSync(
    path.join(fixtureDir, "plugin"),
    path.join(data, "plugins/lifecycle-fixture"),
  );
  const env = environment(root);
  const configure = (packages) =>
    fs.writeFileSync(
      config,
      `[bootstrap.packages]\n${
        Object.entries(packages).map(([name, version]) =>
          `${JSON.stringify(`lifecycle-fixture:${name}`)} = ${
            JSON.stringify(version)
          }`
        ).join("\n")
      }\n`,
    );
  configure({ owned: "1.0.0" });
  return {
    root,
    env,
    work,
    nativeState,
    configure,
    calls() {
      const log = env.FIXTURE_CALL_LOG;
      return fs.existsSync(log)
        ? fs.readFileSync(log, "utf8").trim().split("\n").filter(Boolean).map((
          line,
        ) => JSON.parse(line))
        : [];
    },
    run(args, overrides = {}) {
      return spawnSync(mise, args, {
        cwd: work,
        env: { ...env, ...overrides },
        encoding: "utf8",
        timeout: 20_000,
      });
    },
    start(args, overrides = {}) {
      const child = spawn(mise, args, {
        cwd: work,
        env: { ...env, ...overrides },
        timeout: 20_000,
      });
      let stdout = "";
      let stderr = "";
      child.stdout.setEncoding("utf8").on("data", (text) => {
        stdout += text;
      });
      child.stderr.setEncoding("utf8").on("data", (text) => {
        stderr += text;
      });
      const result = new Promise((resolve, reject) => {
        child.on("error", reject);
        child.on(
          "close",
          (status, signal) => resolve({ status, signal, stdout, stderr }),
        );
      });
      return { child, result };
    },
    installed() {
      return fs.existsSync(nativeState)
        ? JSON.parse(fs.readFileSync(nativeState, "utf8"))
        : {};
    },
  };
}

function succeeded(result) {
  assert.ifError(result.error);
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
}

function snapshot(root) {
  const result = {};
  function visit(dir) {
    for (const name of fs.readdirSync(dir).sort()) {
      const file = path.join(dir, name);
      const relative = path.relative(root, file);
      if (relative === "calls.jsonl") continue;
      const stat = fs.lstatSync(file);
      if (stat.isSymbolicLink()) {
        result[relative] = { link: fs.readlinkSync(file) };
      } else if (stat.isDirectory()) {
        result[relative] = { directory: true };
        visit(file);
      } else {result[relative] = {
          contents: fs.readFileSync(file, "base64"),
          mtime: stat.mtimeMs,
        };}
    }
  }
  visit(root);
  return result;
}

test("mise installs a declared package and prunes it after its declaration is removed", (t) => {
  const h = fixture(t);
  succeeded(
    h.run([
      "bootstrap",
      "packages",
      "apply",
      "--manager",
      "lifecycle-fixture",
      "--yes",
    ]),
  );
  assert.deepEqual(h.installed(), { owned: "1.0.0" });
  h.configure({});
  succeeded(
    h.run([
      "bootstrap",
      "packages",
      "prune",
      "--manager",
      "lifecycle-fixture",
      "--yes",
    ]),
  );
  assert.deepEqual(h.installed(), {});
});

test("partial failed installation retains ownership of the successful package", (t) => {
  const h = fixture(t);
  h.configure({ first: "1.0.0", second: "1.0.0" });
  const failed = h.run([
    "bootstrap",
    "packages",
    "apply",
    "--manager",
    "lifecycle-fixture",
    "--yes",
  ], {
    FIXTURE_FAIL_AFTER: "first",
  });
  assert.ifError(failed.error);
  assert.notEqual(failed.status, 0);
  assert.deepEqual(h.installed(), { first: "1.0.0" });
  h.configure({});
  succeeded(
    h.run([
      "bootstrap",
      "packages",
      "prune",
      "--manager",
      "lifecycle-fixture",
      "--yes",
    ]),
  );
  assert.deepEqual(h.installed(), {});
});

test("healthy apply does not reinstall and pruning preserves preexisting packages", (t) => {
  const h = fixture(t);
  fs.writeFileSync(
    h.nativeState,
    JSON.stringify({ manual: "1.0.0", preexisting: "1.0.0" }),
  );
  h.configure({ owned: "1.0.0", preexisting: "1.0.0" });
  succeeded(
    h.run([
      "bootstrap",
      "packages",
      "apply",
      "--manager",
      "lifecycle-fixture",
      "--yes",
    ]),
  );
  const before = h.calls().filter(({ action }) => action !== "status");
  succeeded(
    h.run([
      "bootstrap",
      "packages",
      "apply",
      "--manager",
      "lifecycle-fixture",
      "--yes",
    ]),
  );
  assert.deepEqual(
    h.calls().filter(({ action }) => action !== "status"),
    before,
  );
  h.configure({});
  succeeded(
    h.run([
      "bootstrap",
      "packages",
      "prune",
      "--manager",
      "lifecycle-fixture",
      "--yes",
    ]),
  );
  assert.deepEqual(h.installed(), { manual: "1.0.0", preexisting: "1.0.0" });
});

test("first status only records mise housekeeping without mutating packages", (t) => {
  const h = fixture(t);
  const before = snapshot(h.root);
  const result = h.run([
    "bootstrap",
    "packages",
    "status",
    "--json",
    "--missing",
  ]);
  assert.ifError(result.error);
  assert.equal(result.status, 1, `${result.stdout}\n${result.stderr}`);
  assert.deepEqual(h.calls().filter(({ action }) => action !== "status"), []);
  const after = snapshot(h.root);
  for (const key of ["state", "state/mise", "state/mise/tracked-configs", "cache", "cache/mise", "cache/mise/plugins", "cache/mise/plugins/lifecycle-fixture"]) {
    if (!Object.hasOwn(before, key) && Object.hasOwn(after, key)) {
      assert.deepEqual(after[key], { directory: true });
      delete after[key];
    }
  }
  const migrated = "state/mise/incomplete-installs/.migrated";
  assert.equal(after[migrated].contents, "");
  delete after[migrated];
  assert.deepEqual(after["state/mise/incomplete-installs"], { directory: true });
  delete after["state/mise/incomplete-installs"];
  const tracked = Object.keys(after).filter((key) =>
    key.startsWith("state/mise/tracked-configs/")
  );
  assert.equal(tracked.length, 1);
  assert.deepEqual(after[tracked[0]], { link: h.env.MISE_GLOBAL_CONFIG_FILE });
  delete after[tracked[0]];
  assert.deepEqual(after, before);
});

test("package status is read-only after an apply has prepared tracking", (t) => {
  const h = fixture(t);
  succeeded(
    h.run([
      "bootstrap",
      "packages",
      "apply",
      "--manager",
      "lifecycle-fixture",
      "--yes",
    ]),
  );
  const before = snapshot(h.root);
  succeeded(h.run(["bootstrap", "packages", "status", "--json", "--missing"]));
  assert.deepEqual(snapshot(h.root), before);
});

test("concurrent applies do not overlap native installation of the same package", async (t) => {
  const h = fixture(t);
  const ready = path.join(h.root, "install-ready");
  const release = path.join(h.root, "install-release");
  const overlap = path.join(h.root, "install-overlap");
  const command = [
    "bootstrap",
    "packages",
    "apply",
    "--manager",
    "lifecycle-fixture",
    "--yes",
  ];
  const overrides = {
    FIXTURE_INSTALL_READY: ready,
    FIXTURE_INSTALL_RELEASE: release,
    FIXTURE_INSTALL_OVERLAP: overlap,
  };
  const first = h.start(command, overrides);
  try {
    const deadline = Date.now() + 5000;
    while (!fs.existsSync(ready) && Date.now() < deadline) await delay(10);
    assert.ok(
      fs.existsSync(ready),
      "first installation did not reach the native command",
    );
    const second = h.start(command, overrides);
    await Promise.race([second.result, delay(1500)]);
    fs.writeFileSync(release, "release\n");
    const results = await Promise.all([first.result, second.result]);
    assert.equal(fs.existsSync(overlap), false, JSON.stringify(results));
    for (const result of results) succeeded(result);
    // A queued apply can replay its plan after acquiring mise's mutation lock.
    const installs = h.calls().filter(({ action }) => action === "install");
    assert.ok(installs.length >= 1 && installs.length <= 2);
  } finally {
    fs.writeFileSync(release, "release\n");
    await first.result;
  }
});

test("interrupted installation follows mise's preexisting-package ownership rule", async (t) => {
  const h = fixture(t);
  const ready = path.join(h.root, "installed-ready");
  const release = path.join(h.root, "installed-release");
  const first = h.start([
    "bootstrap",
    "packages",
    "apply",
    "--manager",
    "lifecycle-fixture",
    "--yes",
  ], {
    FIXTURE_AFTER_INSTALL_READY: ready,
    FIXTURE_AFTER_INSTALL_RELEASE: release,
  });
  try {
    const deadline = Date.now() + 5000;
    while (!fs.existsSync(ready) && Date.now() < deadline) await delay(10);
    assert.ok(
      fs.existsSync(ready),
      "native installation did not reach its completion checkpoint",
    );
    assert.deepEqual(h.installed(), { owned: "1.0.0" });
    assert.equal(first.child.kill("SIGKILL"), true);
    fs.writeFileSync(release, "release\n");
    const interrupted = await first.result;
    assert.equal(interrupted.signal, "SIGKILL");
    succeeded(
      h.run([
        "bootstrap",
        "packages",
        "apply",
        "--manager",
        "lifecycle-fixture",
        "--yes",
      ]),
    );
    h.configure({});
    succeeded(
      h.run([
        "bootstrap",
        "packages",
        "prune",
        "--manager",
        "lifecycle-fixture",
        "--yes",
      ]),
    );
    assert.deepEqual(h.installed(), { owned: "1.0.0" });
    assert.deepEqual(
      h.calls().filter(({ action }) => action === "uninstall"),
      [],
    );
  } finally {
    fs.writeFileSync(release, "release\n");
    await first.result;
  }
});

test("corrupt ownership prevents destructive cleanup and reports failure", (t) => {
  const h = fixture(t);
  succeeded(
    h.run([
      "bootstrap",
      "packages",
      "apply",
      "--manager",
      "lifecycle-fixture",
      "--yes",
    ]),
  );
  const files = Object.keys(snapshot(h.root)).filter((name) =>
    name.startsWith("state/mise/package-plugins/") && name.endsWith(".json")
  );
  assert.equal(files.length, 1, JSON.stringify(Object.keys(snapshot(h.root))));
  fs.writeFileSync(path.join(h.root, files[0]), "{broken ownership\n");
  h.configure({});
  const result = h.run([
    "bootstrap",
    "packages",
    "prune",
    "--manager",
    "lifecycle-fixture",
    "--yes",
  ]);
  assert.ifError(result.error);
  assert.notEqual(result.status, 0, `${result.stdout}\n${result.stderr}`);
  assert.deepEqual(h.installed(), { owned: "1.0.0" });
});

test("failed uninstall retains ownership so the next prune retries it", (t) => {
  const h = fixture(t);
  succeeded(
    h.run([
      "bootstrap",
      "packages",
      "apply",
      "--manager",
      "lifecycle-fixture",
      "--yes",
    ]),
  );
  h.configure({});
  const failed = h.run([
    "bootstrap",
    "packages",
    "prune",
    "--manager",
    "lifecycle-fixture",
    "--yes",
  ], {
    FIXTURE_FAIL_ACTION: "uninstall",
  });
  assert.ifError(failed.error);
  assert.notEqual(failed.status, 0);
  assert.deepEqual(h.installed(), { owned: "1.0.0" });
  succeeded(
    h.run([
      "bootstrap",
      "packages",
      "prune",
      "--manager",
      "lifecycle-fixture",
      "--yes",
    ]),
  );
  assert.deepEqual(h.installed(), {});
});
