// Manages Pi's custom provider config in ~/.pi/agent/models.json — the file Pi
// actually reads custom providers/models from (NOT settings.json; see Pi's
// docs/models.md and dist/config.js `join(getAgentDir(), "models.json")`).
//
// Non-destructive: only the managed `providers.ollama` entry is written; any
// other providers and top-level keys in models.json are preserved. Renders the
// shared mods/agents/ollama-provider.nix source (OpenAI-compatible custom
// provider). apiKey is a required placeholder even though the server is keyless.
//
// Env:
//   OLLAMA_BASE_URL  — base URL of the ollama-compatible endpoint (required to act)
//   OLLAMA_MODELS    — JSON array of model ids to register

const fs = require("node:fs");
const path = require("node:path");

const ollamaBaseUrl = process.env.OLLAMA_BASE_URL;
if (!ollamaBaseUrl) {
  // Nothing declared — leave models.json untouched.
  process.exit(0);
}

let ollamaModels = [];
try {
  ollamaModels = JSON.parse(process.env.OLLAMA_MODELS || "[]");
} catch {
  ollamaModels = [];
}

const modelsPath = path.join(process.env.HOME, ".pi", "agent", "models.json");

let doc = {};
if (fs.existsSync(modelsPath)) {
  try {
    doc = JSON.parse(fs.readFileSync(modelsPath, "utf8"));
  } catch (error) {
    console.error("agents: refusing to update invalid Pi models JSON at " + modelsPath + ": " + error.message);
    process.exit(0);
  }
}

const managedOllama = {
  baseUrl: ollamaBaseUrl,
  api: "openai-completions",
  apiKey: "ollama",
  models: ollamaModels.map((id) => ({ id })),
};

const providers =
  doc.providers && typeof doc.providers === "object" && !Array.isArray(doc.providers) ? doc.providers : {};

if (JSON.stringify(providers.ollama) !== JSON.stringify(managedOllama)) {
  doc.providers = { ...providers, ollama: managedOllama };
  fs.mkdirSync(path.dirname(modelsPath), { recursive: true });
  fs.writeFileSync(modelsPath, JSON.stringify(doc, null, 2) + "\n");
  console.log("agents: applied Pi ollama provider (" + ollamaModels.length + " models) -> " + modelsPath);
}
