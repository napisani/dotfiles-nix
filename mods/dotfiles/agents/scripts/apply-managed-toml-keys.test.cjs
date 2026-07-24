const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "apply-managed-toml-keys.js");

function run(env) {
  return execFileSync(process.execPath, [SCRIPT], {
    env: { ...process.env, ...env },
    encoding: "utf8",
  });
}

function mkTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "apply-managed-toml-keys-test-"));
}

test("declared entries are added into a TOML target", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.toml");
  const state = path.join(dir, "state.json");
  fs.writeFileSync(target, "[features]\nhooks = true\n");

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcp_servers",
    DECLARED_ENTRIES: JSON.stringify({ agentmemory: { command: "/x/agentmemory-mcp" } }),
    STATE_FILE: state,
  });

  const content = fs.readFileSync(target, "utf8");
  assert.match(content, /\[features\]/);
  assert.match(content, /\[mcp_servers\.agentmemory\]/);
  assert.match(content, /command = "\/x\/agentmemory-mcp"/);
});

test("an entry removed from declared is pruned, unrelated sections survive", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.toml");
  const state = path.join(dir, "state.json");
  fs.writeFileSync(target, "[features]\nhooks = true\n\n[mcp_servers.userAdded]\ncommand = \"manual\"\n");

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcp_servers",
    DECLARED_ENTRIES: JSON.stringify({ agentmemory: { command: "/x/bin" } }),
    STATE_FILE: state,
  });
  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcp_servers",
    DECLARED_ENTRIES: JSON.stringify({}),
    STATE_FILE: state,
  });

  const content = fs.readFileSync(target, "utf8");
  assert.match(content, /\[features\]/, "unrelated section must survive");
  assert.match(content, /\[mcp_servers\.userAdded\]/, "user-added entry must survive");
  assert.doesNotMatch(content, /\[mcp_servers\.agentmemory\]/, "undeclared entry must be pruned");
});

test("a corrupted state file skips pruning and is left untouched", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.toml");
  const state = path.join(dir, "state.json");
  fs.writeFileSync(target, "[mcp_servers.agentmemory]\ncommand = \"/x/bin\"\n");
  fs.writeFileSync(state, "garbage");
  const before = fs.readFileSync(state, "utf8");

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcp_servers",
    DECLARED_ENTRIES: JSON.stringify({}),
    STATE_FILE: state,
  });

  const content = fs.readFileSync(target, "utf8");
  assert.match(content, /\[mcp_servers\.agentmemory\]/, "prune must be skipped when state is unreadable");
  assert.equal(fs.readFileSync(state, "utf8"), before, "corrupted state file must not be overwritten");
});

test("exits non-zero when @iarna/toml cannot be resolved", () => {
  const dir = mkTmpDir();
  const isolated = path.join(dir, "isolated.js");
  fs.mkdirSync(path.join(dir, "lib"));
  fs.copyFileSync(SCRIPT, isolated);
  fs.copyFileSync(path.join(__dirname, "lib", "managed-state.js"), path.join(dir, "lib", "managed-state.js"));

  assert.throws(() => {
    execFileSync(process.execPath, [isolated], {
      env: {
        ...process.env,
        TARGET_FILE: path.join(dir, "x.toml"),
        MANAGED_KEY: "mcp_servers",
        DECLARED_ENTRIES: "{}",
        STATE_FILE: path.join(dir, "state.json"),
      },
    });
  }, /Command failed/);
});
