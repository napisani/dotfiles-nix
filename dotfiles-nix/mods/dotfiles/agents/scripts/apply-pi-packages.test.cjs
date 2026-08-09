const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "apply-pi-packages.js");

function mkTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "apply-pi-packages-test-"));
}

function mkPiStub(dir) {
  const binDir = path.join(dir, "bin");
  fs.mkdirSync(binDir, { recursive: true });
  const stub = path.join(binDir, "pi");
  fs.writeFileSync(stub, '#!/usr/bin/env bash\necho "$@" >> "$CALL_LOG"\nexit 0\n');
  fs.chmodSync(stub, 0o755);
  return binDir;
}

function run(dir, env) {
  const binDir = mkPiStub(dir);
  return execFileSync(process.execPath, [SCRIPT], {
    env: { ...process.env, PATH: `${binDir}:${process.env.PATH}`, ...env },
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

  run(dir, { CALL_LOG: log, DECLARED_PACKAGES: JSON.stringify(["npm:pi-vim"]), STATE_FILE: state });

  const calls = readCalls(log);
  assert.ok(!calls.some((c) => c.includes("@ayulab/pi-rewind")));
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
