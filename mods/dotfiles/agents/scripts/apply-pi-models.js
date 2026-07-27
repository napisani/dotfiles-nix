// Manages Pi's custom providers in ~/.pi/agent/models.json — the file Pi
// actually reads custom providers/models from (NOT settings.json; see Pi's
// docs/models.md and dist/config.js `join(getAgentDir(), "models.json")`).
//
// Non-destructive: writes each provider in MANAGED_PROVIDERS, preserving any
// other providers and top-level keys already in models.json. Each managed
// provider is rendered into Pi's OpenAI-compatible custom-provider shape; a
// bare list of model-id strings becomes the `[{ id }]` form Pi expects. apiKey
// is a required placeholder even when the server is keyless.
//
// Env:
//   MANAGED_PROVIDERS — JSON object keyed by provider id, each:
//     { baseUrl, api, apiKey, models: ["<id>", ...] }

const fs = require("node:fs");
const path = require("node:path");

let managed = {};
try {
  managed = JSON.parse(process.env.MANAGED_PROVIDERS || "{}");
} catch {
  managed = {};
}
if (!managed || typeof managed !== "object" || Object.keys(managed).length === 0) {
  process.exit(0); // nothing declared — leave models.json untouched
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

const providers =
  doc.providers && typeof doc.providers === "object" && !Array.isArray(doc.providers) ? doc.providers : {};

let changed = false;
const applied = [];
for (const [id, cfg] of Object.entries(managed)) {
  const rendered = {
    baseUrl: cfg.baseUrl,
    api: cfg.api,
    apiKey: cfg.apiKey,
    models: (cfg.models || []).map((m) => ({ id: m })),
  };
  if (JSON.stringify(providers[id]) !== JSON.stringify(rendered)) {
    providers[id] = rendered;
    changed = true;
  }
  applied.push(id + "(" + (cfg.models || []).length + ")");
}

if (changed) {
  doc.providers = providers;
  fs.mkdirSync(path.dirname(modelsPath), { recursive: true });
  fs.writeFileSync(modelsPath, JSON.stringify(doc, null, 2) + "\n");
  console.log("agents: applied Pi providers -> " + applied.join(", ") + " -> " + modelsPath);
}
