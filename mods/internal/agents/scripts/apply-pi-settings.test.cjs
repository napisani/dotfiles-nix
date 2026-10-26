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

test("removes skill paths an earlier run declared, keeping hand-added ones", () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), "apply-pi-settings-"));
  const settingsPath = path.join(home, ".pi", "agent", "settings.json");
  const stateFile = path.join(home, "state", "pi-skill-paths.json");
  fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
  fs.writeFileSync(settingsPath, JSON.stringify({ skills: ["~/manual-skills"] }));

  const declare = (paths) => run(home, { PI_SKILL_PATHS: JSON.stringify(paths), PI_SKILL_STATE_FILE: stateFile });
  assert.equal(declare(["~/old-skills", "~/kept-skills"]).status, 0);
  assert.equal(declare(["~/kept-skills"]).status, 0);

  assert.deepEqual(JSON.parse(fs.readFileSync(settingsPath, "utf8")).skills, ["~/manual-skills", "~/kept-skills"]);
  assert.deepEqual(JSON.parse(fs.readFileSync(stateFile, "utf8")), ["~/kept-skills"]);
});

test("retires skill paths declared before they were recorded", () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), "apply-pi-settings-"));
  const settingsPath = path.join(home, ".pi", "agent", "settings.json");
  fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
  fs.writeFileSync(settingsPath, JSON.stringify({
    skills: ["~/code/*/apps/*/.agents/skills", "~/code/monorepo/pub/pi-surface/skills", "~/declared-skills"],
  }));

  const result = run(home, { PI_SKILL_PATHS: JSON.stringify(["~/declared-skills"]) });

  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(fs.readFileSync(settingsPath, "utf8")).skills, ["~/declared-skills"]);
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
