const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "apply-pi-settings.js");

// Run the script with HOME pointed at a scratch dir so it reads/writes a
// throwaway ~/.pi/agent/settings.json.
function run(home, env = {}) {
  execFileSync(process.execPath, [SCRIPT], {
    env: { ...process.env, HOME: home, ...env },
    encoding: "utf8",
  });
}

function settingsOf(home) {
  return JSON.parse(fs.readFileSync(path.join(home, ".pi", "agent", "settings.json"), "utf8"));
}

function mkHome() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "pi-settings-test-"));
}

test("renders providers.ollama from OLLAMA_BASE_URL + OLLAMA_MODELS", () => {
  const home = mkHome();
  run(home, {
    OLLAMA_BASE_URL: "https://ollama.example.com/v1",
    OLLAMA_MODELS: JSON.stringify(["qwen3:1.7b", "qwen3:0.6b"]),
  });
  const s = settingsOf(home);
  assert.deepEqual(s.providers.ollama, {
    baseUrl: "https://ollama.example.com/v1",
    api: "openai-completions",
    apiKey: "ollama",
    models: [{ id: "qwen3:1.7b" }, { id: "qwen3:0.6b" }],
  });
});

test("leaves other providers and unmanaged settings untouched", () => {
  const home = mkHome();
  const settingsPath = path.join(home, ".pi", "agent", "settings.json");
  fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
  fs.writeFileSync(
    settingsPath,
    JSON.stringify({
      providers: { openai: { baseUrl: "https://api.openai.com/v1", apiKey: "sk-x" } },
      someUserKey: 42,
    }),
  );
  run(home, {
    OLLAMA_BASE_URL: "https://ollama.example.com/v1",
    OLLAMA_MODELS: JSON.stringify(["qwen3:1.7b"]),
  });
  const s = settingsOf(home);
  assert.deepEqual(s.providers.openai, { baseUrl: "https://api.openai.com/v1", apiKey: "sk-x" }, "other provider preserved");
  assert.equal(s.someUserKey, 42, "unmanaged user key preserved");
  assert.deepEqual(s.providers.ollama.models, [{ id: "qwen3:1.7b" }]);
});

test("updating the declared model set rewrites the ollama models", () => {
  const home = mkHome();
  run(home, { OLLAMA_BASE_URL: "https://o/v1", OLLAMA_MODELS: JSON.stringify(["a", "b"]) });
  run(home, { OLLAMA_BASE_URL: "https://o/v1", OLLAMA_MODELS: JSON.stringify(["a"]) });
  const s = settingsOf(home);
  assert.deepEqual(s.providers.ollama.models, [{ id: "a" }], "removed model 'b' is gone");
});

test("without OLLAMA_BASE_URL, no ollama provider is added", () => {
  const home = mkHome();
  run(home, {});
  const s = settingsOf(home);
  assert.ok(!s.providers || !s.providers.ollama, "no ollama provider when env unset");
});
