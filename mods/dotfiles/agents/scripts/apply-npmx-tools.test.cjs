const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "apply-npmx-tools.js");
const NPM_STUB = path.join(__dirname, "test-fixtures", "apply-npmx-tools", "npm");

function mkTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "apply-npmx-tools-test-"));
}

function run(dir, { declared, legacySeed = [], ...env }) {
  const stateFile = path.join(dir, "state.json");
  const callLog = path.join(dir, "calls.log");
  const inventoryFile = path.join(dir, "inventory.json");
  if (!fs.existsSync(inventoryFile)) fs.writeFileSync(inventoryFile, "{}");

  const result = spawnSync(process.execPath, [SCRIPT], {
    encoding: "utf8",
    env: {
      ...process.env,
      CALL_LOG: callLog,
      DECLARED_TOOLS: JSON.stringify(declared),
      LEGACY_SEED: JSON.stringify(legacySeed),
      NPM_COMMAND: NPM_STUB,
      NPM_INVENTORY: inventoryFile,
      STATE_FILE: stateFile,
      ...env,
    },
  });
  return { result, stateFile, callLog, inventoryFile };
}

function readCalls(file) {
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, "utf8").trim().split("\n").filter(Boolean);
}

function writeInventory(dir, inventory) {
  fs.writeFileSync(path.join(dir, "inventory.json"), JSON.stringify(inventory));
}

const terminalMcp = { name: "@ellery/terminal-mcp", version: "0.5.1" };

test("first run installs the exact declared version and records convergence", () => {
  const dir = mkTmpDir();
  const { result, stateFile, callLog } = run(dir, { declared: [terminalMcp] });

  assert.equal(result.status, 0, result.stderr);
  assert.ok(readCalls(callLog).includes("install -g --no-fund --no-audit @ellery/terminal-mcp@0.5.1"));
  assert.deepEqual(JSON.parse(fs.readFileSync(stateFile, "utf8")), {
    converged: true,
    managed: ["@ellery/terminal-mcp"],
  });
});

test("migration adopts an exact healthy legacy install without reinstalling it", () => {
  const dir = mkTmpDir();
  writeInventory(dir, { "@ellery/terminal-mcp": "0.5.1" });

  const { result, stateFile, callLog } = run(dir, {
    declared: [terminalMcp],
    legacySeed: ["@ellery/terminal-mcp"],
  });

  assert.equal(result.status, 0, result.stderr);
  assert.ok(!readCalls(callLog).some((call) => call.startsWith("install ")));
  assert.deepEqual(JSON.parse(fs.readFileSync(stateFile, "utf8")), {
    converged: true,
    managed: ["@ellery/terminal-mcp"],
  });
});

test("unchanged healthy tools perform no install or uninstall", () => {
  const dir = mkTmpDir();
  const first = run(dir, { declared: [terminalMcp] });
  fs.writeFileSync(first.callLog, "");

  const second = run(dir, { declared: [terminalMcp] });
  const calls = readCalls(second.callLog);
  assert.equal(second.result.status, 0, second.result.stderr);
  assert.ok(!calls.some((call) => call.startsWith("install ")));
  assert.ok(!calls.some((call) => call.startsWith("uninstall ")));
  assert.equal(calls.filter((call) => call.startsWith("ls ")).length, 1);
});

test("adding a declaration installs only the new tool", () => {
  const dir = mkTmpDir();
  const scute = { name: "@napisani/scute", version: "0.0.19" };
  const first = run(dir, { declared: [terminalMcp] });
  fs.writeFileSync(first.callLog, "");

  const second = run(dir, { declared: [terminalMcp, scute] });
  const installs = readCalls(second.callLog).filter((call) => call.startsWith("install "));
  assert.equal(second.result.status, 0, second.result.stderr);
  assert.deepEqual(installs, ["install -g --no-fund --no-audit @napisani/scute@0.0.19"]);
});

test("removing a declaration prunes only the previously managed tool", () => {
  const dir = mkTmpDir();
  const first = run(dir, { declared: [terminalMcp] });
  writeInventory(dir, {
    "@ellery/terminal-mcp": "0.5.1",
    "manually-installed": "9.0.0",
  });
  fs.writeFileSync(first.callLog, "");

  const second = run(dir, { declared: [] });
  const calls = readCalls(second.callLog);
  assert.equal(second.result.status, 0, second.result.stderr);
  assert.ok(calls.includes("uninstall -g @ellery/terminal-mcp"));
  assert.ok(!calls.some((call) => call.includes("manually-installed")));
  assert.deepEqual(JSON.parse(fs.readFileSync(second.inventoryFile, "utf8")), {
    "manually-installed": "9.0.0",
  });
});

test("a mismatched installed version is updated to the exact declaration", () => {
  const dir = mkTmpDir();
  writeInventory(dir, { "@ellery/terminal-mcp": "0.5.0" });

  const { result, callLog } = run(dir, { declared: [terminalMcp] });
  assert.equal(result.status, 0, result.stderr);
  assert.ok(readCalls(callLog).includes("install -g --no-fund --no-audit @ellery/terminal-mcp@0.5.1"));
});

test("mutable tags and version ranges are rejected", () => {
  for (const version of ["latest", "^0.5.0"]) {
    const dir = mkTmpDir();
    const { result, callLog } = run(dir, {
      declared: [{ name: "@ellery/terminal-mcp", version }],
    });
    assert.equal(result.status, 1);
    assert.ok(!readCalls(callLog).some((call) => call.startsWith("install ")));
  }
});

test("a missing managed tool is reinstalled", () => {
  const dir = mkTmpDir();
  const first = run(dir, { declared: [terminalMcp] });
  writeInventory(dir, {});
  fs.writeFileSync(first.callLog, "");

  const repaired = run(dir, { declared: [terminalMcp] });
  assert.equal(repaired.result.status, 0, repaired.result.stderr);
  assert.ok(readCalls(repaired.callLog).includes("install -g --no-fund --no-audit @ellery/terminal-mcp@0.5.1"));
});

test("an unhealthy inventory records non-convergence and revalidates before reinstalling", () => {
  const dir = mkTmpDir();
  const first = run(dir, { declared: [terminalMcp] });
  fs.writeFileSync(first.callLog, "");

  const unhealthy = run(dir, { declared: [terminalMcp], NPM_TREE_INVALID: "1" });
  assert.equal(unhealthy.result.status, 1);
  assert.equal(JSON.parse(fs.readFileSync(unhealthy.stateFile, "utf8")).converged, false);
  assert.ok(readCalls(unhealthy.callLog).includes("install -g --no-fund --no-audit @ellery/terminal-mcp@0.5.1"));

  fs.writeFileSync(first.callLog, "");
  const retried = run(dir, { declared: [terminalMcp] });
  assert.equal(retried.result.status, 0, retried.result.stderr);
  assert.ok(!readCalls(retried.callLog).some((call) => call.startsWith("install ")));
  assert.equal(JSON.parse(fs.readFileSync(retried.stateFile, "utf8")).converged, true);
});

test("a failed install records non-convergence and retries", () => {
  const dir = mkTmpDir();
  const first = run(dir, { declared: [terminalMcp], NPM_FAIL_INSTALL: terminalMcp.name });
  assert.equal(first.result.status, 1);
  assert.equal(JSON.parse(fs.readFileSync(first.stateFile, "utf8")).converged, false);

  fs.writeFileSync(first.callLog, "");
  const second = run(dir, { declared: [terminalMcp] });
  assert.equal(second.result.status, 0, second.result.stderr);
  assert.ok(readCalls(second.callLog).includes("install -g --no-fund --no-audit @ellery/terminal-mcp@0.5.1"));
});

test("a failed uninstall retains ownership and retries pruning", () => {
  const dir = mkTmpDir();
  const first = run(dir, { declared: [terminalMcp] });
  const failed = run(dir, {
    declared: [],
    NPM_FAIL_UNINSTALL: terminalMcp.name,
  });
  assert.equal(failed.result.status, 1);
  assert.deepEqual(JSON.parse(fs.readFileSync(failed.stateFile, "utf8")).managed, [terminalMcp.name]);

  fs.writeFileSync(first.callLog, "");
  const retried = run(dir, { declared: [] });
  assert.equal(retried.result.status, 0, retried.result.stderr);
  assert.ok(readCalls(retried.callLog).includes("uninstall -g @ellery/terminal-mcp"));
});

test("legacy cleanup seeds are pruned once without touching other packages", () => {
  const dir = mkTmpDir();
  writeInventory(dir, { legacy: "1.0.0", manual: "2.0.0" });

  const first = run(dir, { declared: [terminalMcp], legacySeed: ["legacy"] });
  assert.equal(first.result.status, 0, first.result.stderr);
  assert.ok(readCalls(first.callLog).includes("uninstall -g legacy"));
  assert.ok(!readCalls(first.callLog).some((call) => call.includes("uninstall -g manual")));

  fs.writeFileSync(first.callLog, "");
  const second = run(dir, { declared: [terminalMcp], legacySeed: ["legacy"] });
  assert.ok(!readCalls(second.callLog).some((call) => call.includes("legacy")));
});

test("corrupt state is preserved and unknown packages are not pruned", () => {
  const dir = mkTmpDir();
  const stateFile = path.join(dir, "state.json");
  fs.writeFileSync(stateFile, "not json");
  writeInventory(dir, { unknown: "1.0.0" });

  const applied = run(dir, { declared: [terminalMcp] });
  assert.equal(applied.result.status, 1);
  assert.equal(fs.readFileSync(stateFile, "utf8"), "not json");
  assert.ok(!readCalls(applied.callLog).some((call) => call.startsWith("uninstall ")));
  assert.equal(JSON.parse(fs.readFileSync(applied.inventoryFile, "utf8")).unknown, "1.0.0");
});

test("forced repair reinstalls healthy declared tools", () => {
  const dir = mkTmpDir();
  const first = run(dir, { declared: [terminalMcp] });
  fs.writeFileSync(first.callLog, "");

  const repaired = run(dir, { declared: [terminalMcp], FORCE_REPAIR: "1" });
  assert.equal(repaired.result.status, 0, repaired.result.stderr);
  assert.ok(readCalls(repaired.callLog).includes("install -g --no-fund --no-audit @ellery/terminal-mcp@0.5.1"));
});
