const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "uv-reconcile-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const log = path.join(dir, "calls");
  const state = path.join(dir, "state.json");
  const toolbox = path.join(dir, "toolbox");
  const vocal = path.join(dir, "vocal");
  fs.mkdirSync(toolbox);
  const desired = {
    "sqlit-tui": {
      package: "sqlit-tui[postgres]",
      extras: ["postgres"],
      with: ["psycopg2-binary"],
    },
  };
  const run = (tools = desired, extra = {}) =>
    spawnSync(process.execPath, [path.join(__dirname, "apply-uv-tools.js")], {
      encoding: "utf8",
      env: {
        ...process.env,
        FORCE_REPAIR: "",
        STATE_FILE: state,
        DECLARED_TOOLS: JSON.stringify(tools),
        UV_COMMAND: path.join(__dirname, "test-fixtures/apply-uv-tools/uv"),
        PYTHON_COMMAND: process.env.PYTHON_COMMAND || "python3",
        CALL_LOG: log,
        UV_FIXTURE_ROOT: dir,
        TOOLBOX: toolbox,
        ...extra,
      },
    });
  const calls = () =>
    fs.existsSync(log)
      ? fs.readFileSync(log, "utf8").trim().split("\n").filter(Boolean)
      : [];
  return {
    dir,
    toolbox,
    vocal,
    state,
    desired,
    run,
    calls,
    mutations: () => calls().filter((c) => !c.startsWith("--offline")),
    clear: () => fs.writeFileSync(log, ""),
  };
}
function seedLegacyVocal(h) {
  fs.mkdirSync(path.join(h.vocal, "bin"), { recursive: true });
  fs.writeFileSync(path.join(h.vocal, "bin/python"), "fixture");
  const file = path.join(h.vocal, "packages.json");
  fs.writeFileSync(
    file,
    JSON.stringify([
      { name: "requests", version: "1.0.0" },
      { name: "manual", version: "1.0.0" },
    ]),
  );
  const state = JSON.parse(fs.readFileSync(h.state));
  state.entries["venv:vocal"] = {
    spec: { kind: "venv", path: h.vocal, packages: ["requests"] },
    pending: false,
  };
  fs.writeFileSync(h.state, JSON.stringify(state));
  return file;
}
test("sqlit extras converge with no repeat installs", (t) => {
  const h = fixture(t);
  const first = h.run();
  assert.equal(first.status, 0, first.stderr);
  h.clear();
  const second = h.run();
  assert.equal(second.status, 0, second.stderr);
  assert.deepEqual(h.mutations(), []);
  assert.ok(h.calls().every((c) => c.startsWith("--offline")));
});
test("status only observes uv receipts; no state or installations are created", (t) => {
  const h = fixture(t);
  assert.equal(
    h.run(undefined, { RECONCILE_MODE: "status", FORCE_REPAIR: "1" }).status,
    1,
  );
  assert.deepEqual(h.mutations(), []);
  assert.equal(fs.existsSync(h.state), false);
});
test("editable source edits are live; dependency metadata edits reconcile", (t) => {
  const h = fixture(t);
  const dir = path.join(h.toolbox, "read-aloud");
  fs.mkdirSync(dir);
  const project = path.join(dir, "pyproject.toml");
  fs.writeFileSync(
    project,
    '[project]\nname = "read-aloud"\nversion = "1.0.0"\n',
  );
  assert.equal(h.run().status, 0);
  h.clear();
  fs.writeFileSync(path.join(dir, "main.py"), "# edited source\n");
  assert.equal(h.run().status, 0);
  assert.deepEqual(h.mutations(), []);
  fs.appendFileSync(project, 'dependencies = ["requests"]\n');
  h.clear();
  assert.equal(h.run().status, 0);
  assert.deepEqual(h.mutations(), [
    `tool install --force --reinstall-package read-aloud --editable ${
      fs.realpathSync(dir)
    }`,
  ]);
});
test("editable receipt symlinks and canonical paths identify the same source", (t) => {
  const h = fixture(t);
  const dir = path.join(h.toolbox, "read-aloud");
  fs.mkdirSync(dir);
  fs.writeFileSync(
    path.join(dir, "pyproject.toml"),
    '[project]\nname = "read-aloud"\nversion = "1.0.0"\n',
  );
  assert.equal(h.run().status, 0);
  const alias = path.join(h.dir, "alias");
  fs.symlinkSync(dir, alias);
  const receipt = path.join(h.dir, "tools/read-aloud/uv-receipt.toml");
  fs.writeFileSync(
    receipt,
    fs.readFileSync(receipt, "utf8").replace(fs.realpathSync(dir), alias),
  );
  h.clear();
  assert.equal(h.run().status, 0);
  assert.deepEqual(h.mutations(), []);
});
test("failed uv tool retries its installation", (t) => {
  const h = fixture(t);
  assert.equal(h.run(undefined, { UV_FAIL_INSTALL: "sqlit-tui" }).status, 1);
  h.clear();
  assert.equal(h.run().status, 0);
  assert.deepEqual(h.mutations(), [
    "tool install --force --with psycopg2-binary sqlit-tui[postgres]",
  ]);
});
test("uv no longer creates Vocal environments, even with the old variable set", (t) => {
  const h = fixture(t);
  assert.equal(h.run(undefined, { VOCAL_VENV: h.vocal }).status, 0);
  assert.equal(fs.existsSync(h.vocal), false);
  assert.ok(h.mutations().every((c) => c.startsWith("tool install")));
});
test("removed managed tools are uninstalled without touching other inventory", (t) => {
  const h = fixture(t);
  h.run();
  h.clear();
  assert.equal(h.run({}).status, 0);
  assert.deepEqual(h.mutations(), ["tool uninstall sqlit-tui"]);
});
test("removing SQLit keeps editable toolbox tools healthy without reinstalling", t => {
  const h = fixture(t);
  const dir = path.join(h.toolbox, 'read-aloud');
  fs.mkdirSync(dir);
  fs.writeFileSync(path.join(dir, 'pyproject.toml'), '[project]\nname = "read-aloud"\nversion = "1.0.0"\n');
  assert.equal(h.run().status, 0);
  h.clear();
  assert.equal(h.run({}).status, 0);
  assert.deepEqual(h.mutations(), ['tool uninstall sqlit-tui']);
  assert.deepEqual(Object.keys(JSON.parse(fs.readFileSync(h.state)).entries), ['read-aloud']);
  h.clear();
  assert.equal(h.run({}).status, 0);
  assert.deepEqual(h.mutations(), []);
});
test("invalid uv inventory does not cause a force-install loop", (t) => {
  const h = fixture(t);
  h.run();
  h.clear();
  assert.equal(h.run(undefined, { UV_LIST_INVALID: "1" }).status, 1);
  assert.deepEqual(h.mutations(), []);
});
test("missing executable repairs only the affected uv tool", (t) => {
  const h = fixture(t);
  h.run();
  fs.rmSync(path.join(h.dir, "bin/sqlit-tui"));
  h.clear();
  assert.equal(h.run().status, 0);
  assert.equal(h.mutations().length, 1);
});
test("lost extra dependency is repaired, unrelated environments are ignored", (t) => {
  const h = fixture(t);
  h.run();
  fs.writeFileSync(
    path.join(h.dir, "tools/sqlit-tui/packages.json"),
    '[{"name":"sqlit-tui","version":"1.0.0"}]',
  );
  h.clear();
  assert.equal(h.run().status, 0);
  assert.equal(h.mutations().length, 1);
});
test("revoking vocal requirements preserves the venv and unmanaged packages", (t) => {
  const h = fixture(t);
  h.run();
  const file = seedLegacyVocal(h);
  h.clear();
  assert.equal(h.run().status, 0);
  assert.deepEqual(h.mutations(), [
    `pip uninstall --python ${h.vocal}/bin/python requests`,
  ]);
  assert.ok(fs.existsSync(path.join(h.vocal, "bin/python")));
  assert.deepEqual(JSON.parse(fs.readFileSync(file)), [{
    name: "manual",
    version: "1.0.0",
  }]);
});
test("legacy Vocal cleanup retries failures without reinstalling tools", (t) => {
  const h = fixture(t);
  h.run();
  seedLegacyVocal(h);
  h.clear();
  assert.equal(h.run(undefined, { UV_FAIL_PIP_UNINSTALL: "1" }).status, 1);
  h.clear();
  assert.equal(h.run().status, 0);
  assert.deepEqual(h.mutations(), [
    `pip uninstall --python ${h.vocal}/bin/python requests`,
  ]);
  h.clear();
  assert.equal(h.run().status, 0);
  assert.deepEqual(h.mutations(), []);
});
test("completed Vocal migration never probes the old environment again", t => {
  const h = fixture(t);
  h.run();
  seedLegacyVocal(h);
  assert.equal(h.run().status, 0);
  assert.equal(Object.hasOwn(JSON.parse(fs.readFileSync(h.state)).entries, 'venv:vocal'), false);
  for (const mode of ['apply', 'status']) {
    h.clear();
    assert.equal(h.run(undefined, {RECONCILE_MODE:mode}).status, 0);
    assert.ok(!h.calls().some(call => call.includes(h.vocal)), 'retired environment was still probed');
  }
});
test("explicit uv repair requests real reinstalls", (t) => {
  const h = fixture(t);
  h.run();
  h.clear();
  assert.equal(h.run(undefined, { FORCE_REPAIR: "1" }).status, 0);
  assert.ok(
    h.mutations().some((call) =>
      call.startsWith("tool install --force --reinstall ")
    ),
  );
  assert.ok(h.mutations().every((call) => call.startsWith("tool install")));
});
test("corrupt uv state fails closed", (t) => {
  const h = fixture(t);
  fs.writeFileSync(h.state, "bad state");
  assert.equal(h.run().status, 1);
  assert.deepEqual(h.mutations(), []);
  assert.equal(fs.readFileSync(h.state, "utf8"), "bad state");
});
