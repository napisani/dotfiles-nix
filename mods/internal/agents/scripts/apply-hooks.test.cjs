const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");
function harness(t, agent) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "agent-hooks-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const source = path.join(dir, "source.json"),
    target = path.join(dir, "target.json"),
    rtk = path.join(dir, "rtk.json");
  fs.writeFileSync(source, JSON.stringify({}));
  fs.writeFileSync(
    rtk,
    JSON.stringify({
      hooks: {
        PreToolUse: [{
          matcher: "Bash",
          hooks: [{
            type: "command",
            command: "/nix/store/runtime/bin/rtk hook claude",
          }],
        }],
      },
    }),
  );
  const run = (extra = {}) =>
    spawnSync(process.execPath, [
      path.join(__dirname, `apply-${agent}-hooks.js`),
    ], {
      env: {
        ...process.env,
        TARGET_FILE: target,
        SOURCE_FILE: source,
        HOOKS_TARGET_FILE: target,
        HOOKS_SOURCE_FILE: source,
        CONFIG_TOML_FILE: path.join(dir, "config.toml"),
        RTK_SOURCE_FILE: rtk,
        ...extra,
      },
      encoding: "utf8",
    });
  return { dir, target, source, run };
}
test("Claude settings project skill revocation with hooks in the same write", t => {
  const h = harness(t, "claude");
  assert.equal(h.run({SKILL_OVERRIDES:'{"skill":"user-invocable-only"}'}).status, 0);
  const before = fs.readFileSync(h.target, 'utf8');
  assert.equal(h.run({SKILL_OVERRIDES:'{}',RECONCILE_MODE:'status'}).status, 1);
  assert.equal(fs.readFileSync(h.target, 'utf8'), before);
  assert.equal(h.run({SKILL_OVERRIDES:'{}'}).status, 0);
  const result = JSON.parse(fs.readFileSync(h.target));
  assert.deepEqual(result.skillOverrides, {});
  assert.ok(result.hooks.PreToolUse.length);
});
for (const agent of ["claude", "codex"]) {
  test(`${agent}: corrupt shared settings fail closed`, (t) => {
    const h = harness(t, agent);
    fs.writeFileSync(h.target, "not-json");
    assert.equal(h.run().status, 1);
    assert.equal(fs.readFileSync(h.target, "utf8"), "not-json");
    assert.equal(fs.existsSync(h.target + ".corrupted"), false);
  });
}
test("Claude RTK hooks merge idempotently, upgrade, and revoke without touching manual hooks", (t) => {
  const h = harness(t, "claude");
  const manual = {
    matcher: "Bash",
    hooks: [{ type: "command", command: "my-personal-hook" }],
  };
  fs.writeFileSync(
    h.target,
    JSON.stringify({
      hooks: {
        PreToolUse: [{
          ...manual,
          hooks: [...manual.hooks, {
            type: "command",
            command: "rtk hook claude",
          }],
        }],
      },
    }),
  );
  assert.equal(h.run().status, 0);
  const before = fs.statSync(h.target).mtimeMs;
  assert.equal(
    JSON.parse(fs.readFileSync(h.target)).hooks.PreToolUse.length,
    2,
  );
  assert.equal(h.run().status, 0);
  assert.equal(fs.statSync(h.target).mtimeMs, before);
  assert.equal(h.run({ RTK_SOURCE_FILE: "" }).status, 0);
  assert.deepEqual(JSON.parse(fs.readFileSync(h.target)).hooks.PreToolUse, [
    manual,
  ]);
});
