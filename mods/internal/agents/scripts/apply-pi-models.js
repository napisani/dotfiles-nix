// Pi reads custom providers from models.json, not settings.json. Preserve
// native/manual providers outside the explicitly managed IDs.
const path = require("node:path");
const { readJsonObject, writeJsonIfChanged } = require(
  "../../scripts/lib/managed-hooks.js",
);
const managed = JSON.parse(process.env.MANAGED_PROVIDERS || "{}");
const removed = JSON.parse(process.env.REMOVED_PROVIDERS || "[]");
if (
  !managed || typeof managed !== "object" || Array.isArray(managed) ||
  !Array.isArray(removed) || !removed.every((id) => typeof id === "string")
) throw new Error("invalid Pi provider declarations");
if (Object.keys(managed).length || removed.length) {
  const file = path.join(process.env.HOME, ".pi/agent/models.json");
  const doc = readJsonObject(file, {});
  const providers = doc.providers || {};
  if (typeof providers !== "object" || Array.isArray(providers)) {
    throw new Error("invalid Pi providers");
  }
  for (const [id, cfg] of Object.entries(managed)) {
    providers[id] = {
      baseUrl: cfg.baseUrl,
      api: cfg.api,
      apiKey: cfg.apiKey,
      models: (cfg.models || []).map((model) =>
        typeof model === "string" ? { id: model } : model
      ),
    };
  }
  for (const id of removed) delete providers[id];
  doc.providers = providers;
  writeJsonIfChanged(file, doc);
}
