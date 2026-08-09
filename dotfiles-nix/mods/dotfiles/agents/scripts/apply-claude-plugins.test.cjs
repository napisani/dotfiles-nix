const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "apply-claude-plugins.js");

function mkTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "apply-claude-plugins-test-"));
}

// Stubs the `claude` CLI with a script that just logs its argv to CALL_LOG
// and exits 0, so these tests exercise the real diff/prune/refresh logic
// without touching a real Claude Code install.
function mkClaudeStub(dir) {
  const binDir = path.join(dir, "bin");
  fs.mkdirSync(binDir, { recursive: true });
  const stub = path.join(binDir, "claude");
  fs.writeFileSync(stub, '#!/usr/bin/env bash\necho "$@" >> "$CALL_LOG"\nexit 0\n');
  fs.chmodSync(stub, 0o755);
  return binDir;
}

function run(dir, env) {
  const binDir = mkClaudeStub(dir);
  return execFileSync(process.execPath, [SCRIPT], {
    env: { ...process.env, PATH: `${binDir}:${process.env.PATH}`, ...env },
    encoding: "utf8",
  });
}

function readCalls(logFile) {
  if (!fs.existsSync(logFile)) return [];
  return fs.readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean);
}

test("a newly declared plugin gets a full uninstall-then-install cycle", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");

  run(dir, { CALL_LOG: log, DECLARED_PLUGINS: JSON.stringify(["lc@lc"]), STATE_FILE: state });

  const calls = readCalls(log);
  assert.ok(calls.some((c) => c === "plugin uninstall lc@lc --scope user"));
  assert.ok(calls.some((c) => c === "plugin install lc@lc --scope user"));
});

test("an already-managed plugin only gets install, not uninstall, on the next run", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");

  run(dir, { CALL_LOG: log, DECLARED_PLUGINS: JSON.stringify(["lc@lc"]), STATE_FILE: state });
  fs.writeFileSync(log, "");
  run(dir, { CALL_LOG: log, DECLARED_PLUGINS: JSON.stringify(["lc@lc"]), STATE_FILE: state });

  const calls = readCalls(log);
  assert.ok(!calls.some((c) => c.startsWith("plugin uninstall lc@lc")), "should not uninstall an unchanged, already-managed plugin");
  assert.ok(calls.some((c) => c === "plugin install lc@lc --scope user"));
});

test("a plugin removed from declared is uninstalled and not reinstalled", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");

  run(dir, { CALL_LOG: log, DECLARED_PLUGINS: JSON.stringify(["lc@lc", "code@lc"]), STATE_FILE: state });
  fs.writeFileSync(log, "");
  run(dir, { CALL_LOG: log, DECLARED_PLUGINS: JSON.stringify(["lc@lc"]), STATE_FILE: state });

  const calls = readCalls(log);
  assert.ok(calls.some((c) => c === "plugin uninstall code@lc --scope user"), "undeclared plugin should be uninstalled");
  assert.ok(!calls.some((c) => c === "plugin install code@lc --scope user"), "undeclared plugin should not be reinstalled");
});

test("a plugin never managed by Nix (e.g. bundled/official) is never touched", () => {
  const dir = mkTmpDir();
  const log = path.join(dir, "calls.log");
  const state = path.join(dir, "state.json");

  run(dir, { CALL_LOG: log, DECLARED_PLUGINS: JSON.stringify(["lc@lc"]), STATE_FILE: state });

  const calls = readCalls(log);
  assert.ok(!calls.some((c) => c.includes("typescript-lsp@claude-plugins-official")));
});
