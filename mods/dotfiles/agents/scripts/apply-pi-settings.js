// Applies declarative Pi settings to ~/.pi/agent/settings.json.
// Managed object values are deep-merged, and declared skill paths are added
// without removing user-managed paths.
//
// Env vars:
//   PI_MANAGED_SETTINGS — JSON object of settings to enforce
//   PI_SKILL_PATHS      — JSON array of skill search paths to ensure

const fs = require("node:fs");
const path = require("node:path");
const { atomicWriteFileSync } = require("../../scripts/lib/managed-state.js");

const settingsPath = path.join(process.env.HOME, ".pi", "agent", "settings.json");

function parseDeclaration(name, fallback, validate) {
  const raw = process.env[name];
  if (raw === undefined) return fallback;
  try {
    const value = JSON.parse(raw);
    if (!validate(value)) throw new Error("unexpected value shape");
    return value;
  } catch (error) {
    console.error(`agents: invalid ${name}: ${error.message}`);
    process.exit(1);
  }
}

const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
const isStringArray = (value) => Array.isArray(value) && value.every((item) => typeof item === "string");

const managedSettings = parseDeclaration("PI_MANAGED_SETTINGS", {}, isObject);
const managedSkillPaths = parseDeclaration("PI_SKILL_PATHS", [], isStringArray);

let settings = {};
if (fs.existsSync(settingsPath)) {
  try {
    settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
  } catch (error) {
    console.error("agents: refusing to update invalid Pi settings JSON at " + settingsPath + ": " + error.message);
    process.exit(0);
  }
}

const before = JSON.stringify(settings);

function mergeManaged(target, desired) {
  for (const [key, value] of Object.entries(desired)) {
    if (isObject(value) && isObject(target[key])) {
      mergeManaged(target[key], value);
    } else {
      target[key] = value;
    }
  }
}

mergeManaged(settings, managedSettings);

if (managedSkillPaths.length > 0) {
  const skills = Array.isArray(settings.skills) ? [...settings.skills] : [];
  for (const skillPath of managedSkillPaths) {
    if (!skills.includes(skillPath)) skills.push(skillPath);
  }
  settings.skills = skills;
}

// An earlier adapter wrote a plural providers map here. Pi reads custom
// providers from models.json, so remove that known-stale managed value.
if (settings.providers !== undefined) delete settings.providers;

if (JSON.stringify(settings) !== before) {
  fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
  atomicWriteFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
  console.log("agents: applied declared Pi settings");
}
