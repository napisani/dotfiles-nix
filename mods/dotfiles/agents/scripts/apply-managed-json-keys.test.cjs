const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "apply-managed-json-keys.js");

function run(env) {
  return execFileSync(process.execPath, [SCRIPT], {
    env: { ...process.env, ...env },
    encoding: "utf8",
  });
}

function mkTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "apply-managed-json-keys-test-"));
}

test("declared entries are added and updated", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.json");
  const state = path.join(dir, "state.json");
  fs.writeFileSync(target, "{}");

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcpServers",
    DECLARED_ENTRIES: JSON.stringify({ linear: { url: "https://mcp.linear.app/mcp" } }),
    STATE_FILE: state,
  });

  const result = JSON.parse(fs.readFileSync(target, "utf8"));
  assert.deepEqual(result.mcpServers.linear, { url: "https://mcp.linear.app/mcp" });
});

test("an entry removed from declared is pruned on the next run", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.json");
  const state = path.join(dir, "state.json");
  fs.writeFileSync(target, "{}");

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcpServers",
    DECLARED_ENTRIES: JSON.stringify({ linear: {}, figma: {} }),
    STATE_FILE: state,
  });
  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcpServers",
    DECLARED_ENTRIES: JSON.stringify({ linear: {} }),
    STATE_FILE: state,
  });

  const result = JSON.parse(fs.readFileSync(target, "utf8"));
  assert.ok("linear" in result.mcpServers, "linear should still be present");
  assert.ok(!("figma" in result.mcpServers), "figma should have been pruned");
});

test("a user-added entry never declared through Nix is left untouched", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.json");
  const state = path.join(dir, "state.json");
  fs.writeFileSync(target, JSON.stringify({ mcpServers: { userAdded: { command: "manual" } } }));

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcpServers",
    DECLARED_ENTRIES: JSON.stringify({ linear: {} }),
    STATE_FILE: state,
  });
  // Run again with linear removed too — userAdded must survive both runs.
  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcpServers",
    DECLARED_ENTRIES: JSON.stringify({}),
    STATE_FILE: state,
  });

  const result = JSON.parse(fs.readFileSync(target, "utf8"));
  assert.deepEqual(result.mcpServers.userAdded, { command: "manual" });
  assert.ok(!("linear" in result.mcpServers), "linear should have been pruned");
});

test("a corrupted state file skips pruning, still applies additions, and is left untouched", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.json");
  const state = path.join(dir, "state.json");
  fs.writeFileSync(target, JSON.stringify({ mcpServers: { linear: {} } }));
  fs.writeFileSync(state, "not valid json {{{");
  const before = fs.readFileSync(state, "utf8");

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcpServers",
    DECLARED_ENTRIES: JSON.stringify({ figma: {} }),
    STATE_FILE: state,
  });

  const result = JSON.parse(fs.readFileSync(target, "utf8"));
  assert.ok("linear" in result.mcpServers, "prune must be skipped when state is unreadable");
  assert.ok("figma" in result.mcpServers, "additions still apply even when state is unreadable");
  assert.equal(fs.readFileSync(state, "utf8"), before, "corrupted state file must not be overwritten");
});
