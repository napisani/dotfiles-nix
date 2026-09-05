const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { spawnSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "apply-claude-plugins.js");
const STUB_BIN = path.join(__dirname, "test-fixtures", "apply-claude-plugins");

function mkTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "apply-claude-plugins-test-"));
}

function run(dir, env) {
  const callLog = env.CALL_LOG || path.join(dir, "calls.log");
  return spawnSync(process.execPath, [SCRIPT], {
    env: {
      ...process.env,
      PATH: `${STUB_BIN}:${process.env.PATH}`,
      CALL_LOG: callLog,
      CLAUDE_INSTALL_STATE: path.join(dir, "installed.json"),
      ...env,
    },
    encoding: "utf8",
  });
}

function readCalls(logFile) {
  if (!fs.existsSync(logFile)) return [];
  return fs.readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean);
}

function declarations(plugins, state, extra = {}) {
  return {
    DECLARED_PLUGINS: JSON.stringify(plugins),
    MARKETPLACES: JSON.stringify(["owner/marketplace"]),
    STATE_FILE: state,
    ...extra,
  };
}

test("first convergence registers marketplaces and installs declared plugins", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");

  const result = run(dir, { CALL_LOG: log, ...declarations(["plugin@marketplace"], state) });

  assert.equal(result.status, 0, result.stderr);
  const calls = readCalls(log);
  assert.ok(calls.includes("plugin marketplace add owner/marketplace --scope user"));
  assert.ok(calls.includes("plugin install plugin@marketplace --scope user"));
  assert.equal(JSON.parse(fs.readFileSync(state, "utf8")).converged, true);
});

test("unchanged healthy declarations perform no marketplace or install operations", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");
  const env = { CALL_LOG: log, ...declarations(["plugin@marketplace"], state) };
  run(dir, env);
  fs.writeFileSync(log, "");

  const result = run(dir, env);

  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(readCalls(log), ["plugin list --json"]);
});

test("removing a declaration prunes only the previously managed plugin", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");
  run(dir, { CALL_LOG: log, ...declarations(["keep@m", "remove@m"], state) });
  fs.writeFileSync(log, "");

  run(dir, { CALL_LOG: log, ...declarations(["keep@m"], state) });

  const calls = readCalls(log);
  assert.ok(calls.includes("plugin uninstall remove@m --scope user"));
  assert.ok(!calls.some((call) => call.includes("unmanaged@m")));
});

test("a missing managed plugin is repaired", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");
  const env = { CALL_LOG: log, ...declarations(["plugin@m"], state) };
  run(dir, env);
  fs.writeFileSync(path.join(dir, "installed.json"), "[]");
  fs.writeFileSync(log, "");

  run(dir, env);

  assert.ok(readCalls(log).includes("plugin install plugin@m --scope user"));
});

test("forced repair reinstalls healthy declared plugins", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");
  const env = { CALL_LOG: log, ...declarations(["plugin@m"], state) };
  run(dir, env);
  fs.writeFileSync(log, "");

  run(dir, { ...env, FORCE_REPAIR: "1" });

  assert.ok(readCalls(log).includes("plugin uninstall plugin@m --scope user"));
  assert.ok(readCalls(log).includes("plugin install plugin@m --scope user"));
});

test("explicit update refreshes marketplaces and updates plugins", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");
  const env = { CALL_LOG: log, ...declarations(["plugin@m"], state) };
  run(dir, env);
  fs.writeFileSync(log, "");

  const result = run(dir, { ...env, UPDATE: "1" });

  assert.equal(result.status, 0, result.stderr);
  const calls = readCalls(log);
  assert.ok(calls.includes("plugin marketplace update"));
  assert.ok(calls.includes("plugin update plugin@m --scope user --yes"));
  assert.ok(!calls.includes("plugin install plugin@m --scope user"));
});

test("a failed install records non-convergence and retries", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");
  const env = { CALL_LOG: log, ...declarations(["plugin@m"], state) };

  const failed = run(dir, { ...env, CLAUDE_FAIL_INSTALL: "plugin@m" });
  assert.equal(failed.status, 1);
  assert.equal(JSON.parse(fs.readFileSync(state, "utf8")).converged, false);

  fs.writeFileSync(log, "");
  const retried = run(dir, env);
  assert.equal(retried.status, 0, retried.stderr);
  assert.ok(readCalls(log).includes("plugin install plugin@m --scope user"));
});

test("a failed removal retains ownership so pruning is retried", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");
  run(dir, { CALL_LOG: log, ...declarations(["remove@m"], state) });

  const failed = run(dir, {
    CALL_LOG: log,
    ...declarations([], state, { CLAUDE_FAIL_UNINSTALL: "remove@m" }),
  });
  assert.equal(failed.status, 1);
  assert.deepEqual(JSON.parse(fs.readFileSync(state, "utf8")).managed, ["remove@m"]);

  fs.writeFileSync(log, "");
  run(dir, { CALL_LOG: log, ...declarations([], state) });
  assert.ok(readCalls(log).includes("plugin uninstall remove@m --scope user"));
});

test("corrupt state is preserved and does not authorize pruning", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");
  fs.writeFileSync(state, "not-json");
  fs.writeFileSync(path.join(dir, "installed.json"), JSON.stringify(["unmanaged@m"]));

  const result = run(dir, { CALL_LOG: log, ...declarations(["plugin@m"], state) });

  assert.equal(result.status, 1);
  assert.equal(fs.readFileSync(state, "utf8"), "not-json");
  assert.ok(!readCalls(log).includes("plugin uninstall unmanaged@m --scope user"));
});
