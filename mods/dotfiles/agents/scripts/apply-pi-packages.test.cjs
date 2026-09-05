const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "apply-pi-packages.js");
const STUB_BIN = path.join(__dirname, "test-fixtures", "apply-pi-packages");

function mkTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "apply-pi-packages-test-"));
}

function run(dir, env) {
  const home = path.join(dir, "home");
  fs.mkdirSync(path.join(home, ".pi", "agent", "npm"), { recursive: true });
  fs.writeFileSync(path.join(home, ".pi", "agent", "npm", "package.json"), '{}\n');
  const callLog = env.CALL_LOG || path.join(dir, "calls.log");
  const npmCallLog = env.NPM_CALL_LOG || path.join(dir, "npm-calls.log");
  return execFileSync(process.execPath, [SCRIPT], {
    env: {
      ...process.env,
      HOME: home,
      PATH: `${STUB_BIN}:${process.env.PATH}`,
      CALL_LOG: callLog,
      NPM_CALL_LOG: npmCallLog,
      PI_INSTALL_STATE: path.join(dir, "installed-packages"),
      ...env,
    },
    encoding: "utf8",
  });
}

function readCalls(logFile) {
  if (!fs.existsSync(logFile)) return [];
  return fs.readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean);
}

test("a declared package is installed", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");

  run(dir, { CALL_LOG: log, DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]), STATE_FILE: state });

  const calls = readCalls(log);
  assert.ok(calls.includes("install npm:pi-vim"));
});

test("a package removed from declared is pruned on the next run", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");

  run(dir, { CALL_LOG: log, DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim", "npm:pi-web-access"]), STATE_FILE: state });
  fs.writeFileSync(log, "");
  run(dir, { CALL_LOG: log, DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]), STATE_FILE: state });

  const calls = readCalls(log);
  assert.ok(calls.includes("remove npm:pi-web-access"));
  assert.ok(!calls.includes("install npm:pi-web-access"));
});

test("a package never managed by Nix is never touched", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");
  const unmanagedArtifact = path.join(dir, "home/.pi/agent/npm/node_modules/@ayulab/pi-rewind");
  fs.writeFileSync(path.join(dir, "installed-packages"), "npm:@ayulab/pi-rewind\n");
  fs.mkdirSync(unmanagedArtifact, { recursive: true });

  run(dir, { CALL_LOG: log, DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]), STATE_FILE: state });

  const calls = readCalls(log);
  assert.ok(!calls.some((c) => c.includes("remove npm:@ayulab/pi-rewind")));
  assert.ok(fs.existsSync(unmanagedArtifact));
});

test("an exact version change removes the old managed spec and installs the new one", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");

  run(dir, { CALL_LOG: log, DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim@1.0.0"]), STATE_FILE: state });
  fs.writeFileSync(log, "");
  run(dir, { CALL_LOG: log, DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim@2.0.0"]), STATE_FILE: state });

  assert.ok(readCalls(log).includes("remove npm:pi-vim@1.0.0"));
  assert.ok(readCalls(log).includes("install npm:pi-vim@2.0.0"));
});

test("unchanged healthy declarations skip Pi installers and npm reconciliation", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const npmLog = path.join(dir, "npm-calls.log");
  const state = path.join(dir, "state.json");
  const env = {
    CALL_LOG: log,
    NPM_CALL_LOG: npmLog,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    STATE_FILE: state,
  };

  run(dir, env);
  fs.writeFileSync(log, "");
  fs.writeFileSync(npmLog, "");
  run(dir, env);

  assert.ok(!readCalls(log).some((call) => /^(install|remove) /.test(call)));
  assert.ok(!readCalls(npmLog).some((call) => call.startsWith("install ")));
});

test("forced repair reconciles an otherwise healthy declaration", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");

  const env = {
    CALL_LOG: log,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    STATE_FILE: state,
  };
  run(dir, env);
  fs.writeFileSync(log, "");
  run(dir, { ...env, FORCE_REPAIR: "1" });

  assert.ok(readCalls(log).includes("install npm:pi-vim"));
});

test("a failed install does not record success and is retried", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");

  assert.doesNotThrow(() => run(dir, {
    CALL_LOG: log,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    PI_FAIL_INSTALL: "npm:pi-vim",
    STATE_FILE: state,
  }));
  assert.equal(JSON.parse(fs.readFileSync(state, "utf8")).converged, false);

  run(dir, {
    CALL_LOG: log,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    STATE_FILE: state,
  });
  assert.ok(readCalls(log).filter((call) => call === "install npm:pi-vim").length >= 2);
});

test("a failed forced repair invalidates prior success so the next run retries", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");
  const env = {
    CALL_LOG: log,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    STATE_FILE: state,
  };

  run(dir, env);
  run(dir, { ...env, FORCE_REPAIR: "1", PI_FAIL_INSTALL: "npm:pi-vim" });
  assert.equal(JSON.parse(fs.readFileSync(state, "utf8")).converged, false);

  fs.writeFileSync(log, "");
  run(dir, env);
  assert.ok(readCalls(log).includes("install npm:pi-vim"));
});

test("a failed removal keeps old ownership so pruning is retried", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");
  const initial = JSON.stringify(["npm:pi-vim", "npm:pi-web-access"]);

  run(dir, { CALL_LOG: log, DECLARED_PACKAGES: initial, STATE_FILE: state });
  fs.writeFileSync(log, "");
  run(dir, {
    CALL_LOG: log,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    PI_FAIL_REMOVE: "npm:pi-web-access",
    STATE_FILE: state,
  });
  assert.deepEqual(JSON.parse(fs.readFileSync(state, "utf8")).managed, ["npm:pi-vim", "npm:pi-web-access"]);

  fs.writeFileSync(log, "");
  run(dir, {
    CALL_LOG: log,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    STATE_FILE: state,
  });
  assert.ok(readCalls(log).includes("remove npm:pi-web-access"));
});

test("a missing declared artifact forces reconciliation", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const npmLog = path.join(dir, "npm-calls.log");
  const state = path.join(dir, "state.json");

  run(dir, {
    CALL_LOG: log,
    NPM_CALL_LOG: npmLog,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    STATE_FILE: state,
  });
  fs.rmSync(path.join(dir, "home/.pi/agent/npm/node_modules/pi-vim"), { recursive: true });
  fs.writeFileSync(log, "");
  fs.writeFileSync(npmLog, "");
  run(dir, {
    CALL_LOG: log,
    NPM_CALL_LOG: npmLog,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    STATE_FILE: state,
  });

  assert.ok(readCalls(log).includes("install npm:pi-vim"));
  assert.ok(readCalls(npmLog).some((call) => call.startsWith("install ")));
});

test("Pi list warnings force reconciliation", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");

  run(dir, { CALL_LOG: log, DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]), STATE_FILE: state });
  fs.writeFileSync(log, "");
  run(dir, {
    CALL_LOG: log,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    PI_LIST_WARNING: "Failed to load extension",
    STATE_FILE: state,
  });

  assert.ok(readCalls(log).includes("install npm:pi-vim"));
});

test("an invalid npm tree forces reconciliation", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const npmLog = path.join(dir, "npm-calls.log");
  const state = path.join(dir, "state.json");

  run(dir, { CALL_LOG: log, NPM_CALL_LOG: npmLog, DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]), STATE_FILE: state });
  fs.writeFileSync(log, "");
  fs.writeFileSync(npmLog, "");
  run(dir, {
    CALL_LOG: log,
    NPM_CALL_LOG: npmLog,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    NPM_HEALTH: "invalid",
    STATE_FILE: state,
  });

  assert.ok(readCalls(log).includes("install npm:pi-vim"));
  assert.ok(readCalls(npmLog).some((call) => call.startsWith("install ")));
});

test("failed npm reconciliation records an unsuccessful run and retries", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");
  const env = {
    CALL_LOG: log,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    STATE_FILE: state,
  };

  run(dir, { ...env, NPM_FAIL_INSTALL: "1" });
  assert.equal(JSON.parse(fs.readFileSync(state, "utf8")).converged, false);

  fs.writeFileSync(log, "");
  run(dir, env);
  assert.ok(readCalls(log).includes("install npm:pi-vim"));
});

test("corrupt state skips unknown pruning and remains available for recovery", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");
  fs.writeFileSync(state, "not json");
  fs.writeFileSync(path.join(dir, "installed-packages"), "npm:unknown\\n");

  run(dir, {
    CALL_LOG: log,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    STATE_FILE: state,
  });

  assert.ok(!readCalls(log).some((call) => call === "remove npm:unknown"));
  assert.equal(fs.readFileSync(state, "utf8"), "not json");
  assert.ok(readCalls(log).includes("install npm:pi-vim"));
});

test("legacySeed removes a legacy package on first run, but only once", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");

  run(dir, {
    CALL_LOG: log,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    LEGACY_SEED: JSON.stringify(["npm:pi-skillful"]),
    STATE_FILE: state,
  });
  const firstRunCalls = readCalls(log);
  assert.ok(firstRunCalls.includes("remove npm:pi-skillful"), "legacy package should be removed on first run");

  fs.writeFileSync(log, "");
  run(dir, {
    CALL_LOG: log,
    DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]),
    LEGACY_SEED: JSON.stringify(["npm:pi-skillful"]),
    STATE_FILE: state,
  });
  const secondRunCalls = readCalls(log);
  assert.ok(!secondRunCalls.some((c) => c.includes("pi-skillful")), "legacy seed should not re-trigger once state file exists");
});
