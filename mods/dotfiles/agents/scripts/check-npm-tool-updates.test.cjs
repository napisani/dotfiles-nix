const assert = require("node:assert/strict");
const path = require("node:path");
const test = require("node:test");
const { spawnSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "check-npm-tool-updates.js");
const NPM_STUB = path.join(__dirname, "test-fixtures", "apply-npmx-tools", "npm");
const declarations = [
  { name: "tool-a", version: "1.0.0" },
  { name: "tool-b", version: "2.0.0" },
];

function run(env = {}) {
  return spawnSync(process.execPath, [SCRIPT], {
    encoding: "utf8",
    env: {
      ...process.env,
      CALL_LOG: "/dev/null",
      DECLARED_TOOLS: JSON.stringify(declarations),
      NPM_COMMAND: NPM_STUB,
      NPM_INVENTORY: "/dev/null",
      ...env,
    },
  });
}

test("reports available versions without changing declarations", () => {
  const result = run({ NPM_LATEST: JSON.stringify({ "tool-a": "1.1.0", "tool-b": "2.0.0" }) });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /tool-a\s+1\.0\.0 -> 1\.1\.0/);
  assert.doesNotMatch(result.stdout, /tool-b\s+2\.0\.0 ->/);
});

test("reports when all exact declarations are current", () => {
  const result = run({ NPM_LATEST: JSON.stringify({ "tool-a": "1.0.0", "tool-b": "2.0.0" }) });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /all declared global npm tools are current/);
});

test("fails visibly when an upstream version cannot be checked", () => {
  const result = run({
    NPM_LATEST: JSON.stringify({ "tool-a": "1.0.0", "tool-b": "2.0.0" }),
    NPM_FAIL_VIEW: "tool-b",
  });

  assert.equal(result.status, 1);
  assert.match(result.stderr, /tool-b/);
});
