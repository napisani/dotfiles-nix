const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "apply-pi-models.js");

// Run with HOME pointed at a scratch dir so it reads/writes a throwaway
// ~/.pi/agent/models.json.
function run(home, env = {}) {
  execFileSync(process.execPath, [SCRIPT], {
    env: { ...process.env, HOME: home, ...env },
    encoding: "utf8",
  });
}

function modelsOf(home) {
  return JSON.parse(fs.readFileSync(path.join(home, ".pi", "agent", "models.json"), "utf8"));
}

function mkHome() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "pi-models-test-"));
}

test("writes providers.ollama into models.json from env", () => {
  const home = mkHome();
  run(home, {
    OLLAMA_BASE_URL: "https://ollama.example.com/v1",
    OLLAMA_MODELS: JSON.stringify(["qwen3:1.7b", "qwen3:0.6b"]),
  });
  assert.deepEqual(modelsOf(home).providers.ollama, {
    baseUrl: "https://ollama.example.com/v1",
    api: "openai-completions",
    apiKey: "ollama",
    models: [{ id: "qwen3:1.7b" }, { id: "qwen3:0.6b" }],
  });
});

test("preserves other providers and top-level keys in models.json", () => {
  const home = mkHome();
  const modelsPath = path.join(home, ".pi", "agent", "models.json");
  fs.mkdirSync(path.dirname(modelsPath), { recursive: true });
  fs.writeFileSync(
    modelsPath,
    JSON.stringify({
      providers: { anthropic: { baseUrl: "https://my-proxy/v1", api: "anthropic-messages" } },
      someUserKey: 7,
    }),
  );
  run(home, { OLLAMA_BASE_URL: "https://o/v1", OLLAMA_MODELS: JSON.stringify(["qwen3:1.7b"]) });
  const d = modelsOf(home);
  assert.deepEqual(
    d.providers.anthropic,
    { baseUrl: "https://my-proxy/v1", api: "anthropic-messages" },
    "other provider preserved",
  );
  assert.equal(d.someUserKey, 7, "unmanaged key preserved");
  assert.deepEqual(d.providers.ollama.models, [{ id: "qwen3:1.7b" }]);
});

test("updating the declared model set rewrites the ollama models", () => {
  const home = mkHome();
  run(home, { OLLAMA_BASE_URL: "https://o/v1", OLLAMA_MODELS: JSON.stringify(["a", "b"]) });
  run(home, { OLLAMA_BASE_URL: "https://o/v1", OLLAMA_MODELS: JSON.stringify(["a"]) });
  assert.deepEqual(modelsOf(home).providers.ollama.models, [{ id: "a" }], "removed model 'b' is gone");
});

test("without OLLAMA_BASE_URL, models.json is not created", () => {
  const home = mkHome();
  run(home, {});
  assert.ok(!fs.existsSync(path.join(home, ".pi", "agent", "models.json")), "no models.json when env unset");
});
