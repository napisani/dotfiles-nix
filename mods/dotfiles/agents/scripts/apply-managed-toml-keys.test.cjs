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

function runExpectFail(env) {
  try {
    execFileSync(process.execPath, [SCRIPT], {
      env: { ...process.env, ...env },
      encoding: "utf8",
      stdio: "pipe",
    });
    return null;
  } catch (e) {
    return e;
  }
}

function mkTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "apply-managed-toml-keys-test-"));
}

test("declared entries land under the managed key, unrelated sections survive", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.toml");
  fs.writeFileSync(target, "[features]\nhooks = true\n");

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcp_servers",
    DECLARED_ENTRIES: JSON.stringify({ agentmemory: { command: "/x/agentmemory-mcp" } }),
  });

  const content = fs.readFileSync(target, "utf8");
  assert.match(content, /\[features\]/, "unrelated section survives");
  assert.match(content, /\[mcp_servers\.agentmemory\]/);
  assert.match(content, /command = "\/x\/agentmemory-mcp"/);
});

test("an entry under the managed key but not declared is removed, with no state file", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.toml");
  fs.writeFileSync(
    target,
    "[features]\nhooks = true\n\n[mcp_servers.agentmemory]\ncommand = \"/x/bin\"\n\n[mcp_servers.userAdded]\ncommand = \"manual\"\n",
  );

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcp_servers",
    DECLARED_ENTRIES: JSON.stringify({ agentmemory: { command: "/x/bin" } }),
  });

  const content = fs.readFileSync(target, "utf8");
  assert.match(content, /\[features\]/, "unrelated section survives");
  assert.match(content, /\[mcp_servers\.agentmemory\]/, "declared entry present");
  assert.doesNotMatch(content, /userAdded/, "hand-added entry does not survive full ownership");
  assert.deepEqual(
    fs.readdirSync(dir).filter((f) => f !== "target.toml"),
    [],
    "no state file written",
  );
});

test("invalid target TOML exits 1 and leaves the file untouched", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "target.toml");
  const garbage = "this is = = not valid toml [[[";
  fs.writeFileSync(target, garbage);

  const err = runExpectFail({
    TARGET_FILE: target,
    MANAGED_KEY: "mcp_servers",
    DECLARED_ENTRIES: JSON.stringify({ agentmemory: {} }),
  });

  assert.ok(err, "script should have exited non-zero");
  assert.equal(err.status, 1, "exit code 1 on unparsable target");
  assert.equal(fs.readFileSync(target, "utf8"), garbage, "target left untouched");
});

test("a missing target file is created with just the managed key", () => {
  const dir = mkTmpDir();
  const target = path.join(dir, "nested", "config.toml");

  run({
    TARGET_FILE: target,
    MANAGED_KEY: "mcp_servers",
    DECLARED_ENTRIES: JSON.stringify({ agentmemory: { command: "/x/bin" } }),
  });

  const content = fs.readFileSync(target, "utf8");
  assert.match(content, /\[mcp_servers\.agentmemory\]/);
  assert.doesNotMatch(content, /\[features\]/);
});

test("exits non-zero when @iarna/toml cannot be resolved", () => {
  const dir = mkTmpDir();
  // Mirror the real layout so the script's `require("../../scripts/lib/...")`
  // resolves, while placing everything in a fresh dir with no node_modules
  // ancestor so @iarna/toml genuinely cannot be resolved.
  const scriptDir = path.join(dir, "agents", "scripts");
  const libDir = path.join(dir, "scripts", "lib");
  fs.mkdirSync(scriptDir, { recursive: true });
  fs.mkdirSync(libDir, { recursive: true });
  const isolated = path.join(scriptDir, "isolated.js");
  fs.copyFileSync(SCRIPT, isolated);
  fs.copyFileSync(
    path.join(__dirname, "..", "..", "scripts", "lib", "managed-state.js"),
    path.join(libDir, "managed-state.js"),
  );

  let err = null;
  try {
    execFileSync(process.execPath, [isolated], {
      env: {
        ...process.env,
        TARGET_FILE: path.join(dir, "x.toml"),
        MANAGED_KEY: "mcp_servers",
        DECLARED_ENTRIES: "{}",
      },
      stdio: "pipe",
    });
  } catch (e) {
    err = e;
  }
  assert.ok(err, "isolated script (no @iarna/toml) should exit non-zero");
  assert.equal(err.status, 1, "exit code 1 when @iarna/toml missing");
});
