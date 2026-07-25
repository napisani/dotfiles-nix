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

function runExpectFail(env) {
  try {
    execFileSync(process.execPath, [SCRIPT], {
      env: { ...process.env, ...env },
      encoding: "utf8",
      stdio: "pipe",
    });
    return null; // did not fail
  } catch (e) {
    return e; // e.status is the exit code
  }
}

function mkTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "apply-managed-json-keys-test-"));
}

test("declared entries replace the managed key", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.json");
  fs.writeFileSync(target, "{}");

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcpServers",
    DECLARED_ENTRIES: JSON.stringify({ linear: { url: "https://mcp.linear.app/mcp" } }),
  });

  const result = JSON.parse(fs.readFileSync(target, "utf8"));
  assert.deepEqual(result.mcpServers, { linear: { url: "https://mcp.linear.app/mcp" } });
});

test("an entry under the managed key but not declared is removed, with no state file", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.json");
  fs.writeFileSync(target, JSON.stringify({ mcpServers: { linear: {}, figma: {}, userAdded: { command: "manual" } } }));

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcpServers",
    DECLARED_ENTRIES: JSON.stringify({ linear: {} }),
  });

  const result = JSON.parse(fs.readFileSync(target, "utf8"));
  // Full ownership: the managed key is rewritten from the declaration alone.
  assert.deepEqual(result.mcpServers, { linear: {} });
  assert.ok(!("figma" in result.mcpServers), "undeclared entry removed");
  assert.ok(!("userAdded" in result.mcpServers), "hand-added entry does not survive full ownership");
  // No state file should have been created anywhere in the dir.
  assert.deepEqual(
    fs.readdirSync(dir).filter((f) => f !== "target.json"),
    [],
    "no state file written",
  );
});

test("sibling top-level keys are preserved byte-for-byte", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.json");
  fs.writeFileSync(
    target,
    JSON.stringify({
      mcpServers: { stale: {} },
      oauthAccount: { token: "secret", refresh: "r" },
      projects: { "/some/path": { allowedTools: [] } },
    }),
  );

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcpServers",
    DECLARED_ENTRIES: JSON.stringify({ agentmemory: { command: "/bin/x" } }),
  });

  const result = JSON.parse(fs.readFileSync(target, "utf8"));
  assert.deepEqual(result.mcpServers, { agentmemory: { command: "/bin/x" } });
  assert.deepEqual(result.oauthAccount, { token: "secret", refresh: "r" }, "sibling key untouched");
  assert.deepEqual(result.projects, { "/some/path": { allowedTools: [] } }, "sibling key untouched");
});

test("invalid target JSON exits 1 and leaves the file untouched", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.json");
  const garbage = "not json {{{";
  fs.writeFileSync(target, garbage);

  const err = runExpectFail({
    TARGET_FILE: target,
    MANAGED_KEY: "mcpServers",
    DECLARED_ENTRIES: JSON.stringify({ linear: {} }),
  });

  assert.ok(err, "script should have exited non-zero");
  assert.equal(err.status, 1, "exit code 1 on unparsable target");
  assert.equal(fs.readFileSync(target, "utf8"), garbage, "target left untouched");
});

test("a missing target file is created with just the managed key", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "nested", "target.json");

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcpServers",
    DECLARED_ENTRIES: JSON.stringify({ linear: {} }),
  });

  const result = JSON.parse(fs.readFileSync(target, "utf8"));
  assert.deepEqual(result, { mcpServers: { linear: {} } });
});
