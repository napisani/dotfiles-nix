const assert = require("node:assert/strict");
const fs = require("node:fs"),
  os = require("node:os"),
  path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");
for (
  const adapter of [
    "managed-file",
    "managed-json-keys",
    "claude-hooks",
    "codex-hooks",
    "codex-config",
    "pi-settings",
    "pi-models",
    "loancrate-config",
  ]
) {
  test(`${adapter}: status projects configuration without writing, apply converges`, (t) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "config-status-"));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const source = path.join(dir, "source.json");
    fs.writeFileSync(source, "{}");
    const env = {
      ...process.env,
      HOME: dir,
      RTK_SOURCE_FILE: "",
      SOURCE_FILE: source,
      TARGET_FILE: path.join(dir, "config"),
      DECLARED_CONTENT: "managed",
      MANAGED_KEY: "managed",
      DECLARED_ENTRIES: '{"one":true}',
      HOOKS_SOURCE_FILE: source,
      HOOKS_TARGET_FILE: path.join(dir, "hooks.json"),
      CONFIG_TOML_FILE: path.join(dir, "config.toml"),
      PI_MANAGED_SETTINGS: '{"theme":"test"}',
      PI_SKILL_PATHS: "[]",
      MANAGED_PROVIDERS: '{"test":{"models":["test"]}}',
      REMOVED_PROVIDERS: "[]",
      LOANCRATE_BASE_CONFIG: '{"one":true}',
    };
    const run = (mode) =>
      spawnSync(
        process.execPath,
        [path.join(__dirname, adapter === 'managed-file' ? '../../scripts/apply-managed-file.js' : `apply-${adapter}.js`)],
        { env: { ...env, RECONCILE_MODE: mode }, encoding: "utf8" },
      );
    const status = run("status");
    assert.equal(status.status, 1, status.stderr);
    assert.match(status.stdout, /config: drift/);
    assert.deepEqual(fs.readdirSync(dir), ["source.json"]);
    const applied = run("apply");
    assert.equal(applied.status, 0, applied.stderr);
    if (adapter === "managed-file") {
      assert.equal(fs.statSync(env.TARGET_FILE).mode & 0o777, 0o600);
      fs.writeFileSync(env.TARGET_FILE, "drift");
      assert.equal(run("apply").status, 0);
      assert.equal(fs.statSync(env.TARGET_FILE).mode & 0o777, 0o600);
    }
    const healthy = run("status");
    assert.equal(healthy.status, 0, healthy.stdout + healthy.stderr);
  });
}
