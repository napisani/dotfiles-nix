// Shape-only JSON hook merging; native adapters define ownership predicates.
const fs = require("node:fs");
const { writeConfigFile } = require("./config-file.js");
function readJsonObject(file, fallback = null) {
  if (!fs.existsSync(file)) return fallback;
  const value = JSON.parse(fs.readFileSync(file, "utf8"));
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`invalid object at ${file}`);
  }
  return value;
}
function writeJsonIfChanged(file, value) {
  const next = JSON.stringify(value, null, 2) + "\n";
  if (fs.existsSync(file) && fs.readFileSync(file, "utf8") === next) return;
  writeConfigFile(file, next);
}
function replaceManagedHooks(current, desired, isManaged) {
  const result = {};
  for (
    const event of new Set([...Object.keys(current), ...Object.keys(desired)])
  ) {
    const retained = (current[event] || []).flatMap((group) => {
      if (!Array.isArray(group?.hooks)) return isManaged(group) ? [] : [group];
      const hooks = group.hooks.filter((handler) => !isManaged(handler));
      return hooks.length || !group.hooks.length ? [{ ...group, hooks }] : [];
    });
    const entries = [...retained, ...(desired[event] || [])];
    if (entries.length) result[event] = entries;
  }
  return result;
}
module.exports = { readJsonObject, writeJsonIfChanged, replaceManagedHooks };
