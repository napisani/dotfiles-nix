const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { spawnSync } = require("node:child_process");

const script = path.join(__dirname, "apply-pi-settings.js");

function run(home, env = {}) {
  return spawnSync(process.execPath, [script], {
    encoding: "utf8",
    env: { ...process.env, HOME: home, ...env },
  });
}

test("applies declared Pi settings and skill paths while preserving unmanaged values", () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), "apply-pi-settings-"));
  const settingsPath = path.join(home, ".pi", "agent", "settings.json");
  fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
  fs.writeFileSync(settingsPath, JSON.stringify({
    custom: true,
    openaiReasoningMode: { effort: "high", fast: true },
    packages: ["manual-package", "npm:pi-subagents"],
    skills: ["~/manual-skills"],
  }));

  const result = run(home, {
    PI_MANAGED_SETTINGS: JSON.stringify({
      defaultProvider: "declared-provider",
      openaiReasoningMode: { fast: false },
      theme: "declared-theme",
    }),
    PI_SKILL_PATHS: JSON.stringify(["~/declared-skills"]),
  });

  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(fs.readFileSync(settingsPath, "utf8")), {
    custom: true,
    openaiReasoningMode: { effort: "high", fast: false },
    packages: ["manual-package", "npm:pi-subagents"],
    skills: ["~/manual-skills", "~/declared-skills"],
    defaultProvider: "declared-provider",
    theme: "declared-theme",
  });
});

test("rejects invalid declaration JSON without changing settings", () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), "apply-pi-settings-"));
  const settingsPath = path.join(home, ".pi", "agent", "settings.json");
  fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
  fs.writeFileSync(settingsPath, "{\"custom\":true}\n");

  const result = run(home, { PI_MANAGED_SETTINGS: "not-json" });

  assert.equal(result.status, 1);
  assert.match(result.stderr, /PI_MANAGED_SETTINGS/);
  assert.equal(fs.readFileSync(settingsPath, "utf8"), "{\"custom\":true}\n");
});
