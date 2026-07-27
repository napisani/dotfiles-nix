const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "apply-pi-models.js");

// Run with HOME pointed at a scratch dir so it reads/writes a throwaway
// ~/.pi/agent/models.json.
function run(home, managedProviders) {
  execFileSync(process.execPath, [SCRIPT], {
    env: { ...process.env, HOME: home, MANAGED_PROVIDERS: JSON.stringify(managedProviders) },
    encoding: "utf8",
  });
}

function modelsOf(home) {
  return JSON.parse(fs.readFileSync(path.join(home, ".pi", "agent", "models.json"), "utf8"));
}

function mkHome() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "pi-models-test-"));
}

const ollama = { baseUrl: "https://o/v1", api: "openai-completions", apiKey: "ollama", models: ["qwen3:1.7b"] };
const mlx = {
  baseUrl: "http://localhost:8080/v1",
  api: "openai-completions",
  apiKey: "mlx",
  models: ["mlx-community/Qwen3-1.7B-4bit", "baa-ai/Qwen3.6-35B-A3B-RAM-25GB-MLX"],
};

test("renders each managed provider into models.json (id-string -> {id})", () => {
  const home = mkHome();
  run(home, { ollama, mlx });
  const d = modelsOf(home);
  assert.deepEqual(d.providers.ollama, { ...ollama, models: [{ id: "qwen3:1.7b" }] });
  assert.deepEqual(d.providers.mlx.baseUrl, "http://localhost:8080/v1");
  assert.deepEqual(d.providers.mlx.models, [
    { id: "mlx-community/Qwen3-1.7B-4bit" },
    { id: "baa-ai/Qwen3.6-35B-A3B-RAM-25GB-MLX" },
  ]);
});

test("preserves other providers and top-level keys", () => {
  const home = mkHome();
  const p = path.join(home, ".pi", "agent", "models.json");
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, JSON.stringify({ providers: { anthropic: { api: "anthropic-messages" } }, k: 1 }));
  run(home, { mlx });
  const d = modelsOf(home);
  assert.deepEqual(d.providers.anthropic, { api: "anthropic-messages" }, "other provider preserved");
  assert.equal(d.k, 1, "unmanaged key preserved");
  assert.ok(d.providers.mlx, "mlx provider added");
});

test("updating a provider's model set rewrites its models", () => {
  const home = mkHome();
  run(home, { mlx });
  run(home, { mlx: { ...mlx, models: ["mlx-community/Qwen3-1.7B-4bit"] } });
  assert.deepEqual(modelsOf(home).providers.mlx.models, [{ id: "mlx-community/Qwen3-1.7B-4bit" }]);
});

test("empty MANAGED_PROVIDERS leaves models.json uncreated", () => {
  const home = mkHome();
  run(home, {});
  assert.ok(!fs.existsSync(path.join(home, ".pi", "agent", "models.json")));
});
