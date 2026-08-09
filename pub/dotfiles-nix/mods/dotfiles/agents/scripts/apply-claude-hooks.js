// Merges Workmux window-status hooks (+ optional extra settings) into
// Claude Code's settings.json. Non-destructive: replaces only managed
// workmux hook entries, preserving user-added hooks.
//
// Env vars:
//   TARGET_FILE     — path to ~/.claude/settings.json
//   SOURCE_FILE     — path to the workmux claude-hooks.json to merge in
//   EXTRA_SETTINGS  — optional JSON object always merged into the target
//                     (one-level-deep — nested objects like `permissions`
//                     are merged key-by-key, not replaced wholesale)

const fs = require("node:fs");
const path = require("node:path");

const targetFile = process.env.TARGET_FILE;
const sourceFile = process.env.SOURCE_FILE;

function readJson(file, fallback) {
  try {
    if (!fs.existsSync(file)) return fallback;
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    const backup = file + ".corrupted";
    try {
      fs.renameSync(file, backup);
    } catch {}
    console.error("agents: invalid JSON at " + file + " — renamed to " + backup + " and starting fresh: " + error.message);
    return fallback;
  }
}

function writeJsonIfChanged(file, value) {
  const next = JSON.stringify(value, null, 2) + "\n";
  const current = fs.existsSync(file) ? fs.readFileSync(file, "utf8") : "";
  if (current === next) return;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, next);
  console.log("agents: applied Claude Workmux status hooks -> " + file);
}

// One-level-deep merge: nested plain objects (e.g. `permissions`) are merged
// key-by-key into any existing object at that key, instead of replacing it
// wholesale — so pushing `{ permissions: { defaultMode: "auto" } }` doesn't
// clobber a `permissions.allow`/`permissions.deny` list set up elsewhere.
function mergeSettingsInto(target, extraSettings) {
  for (const [key, value] of Object.entries(extraSettings)) {
    const isPlainObject = (v) => v && typeof v === "object" && !Array.isArray(v);
    if (isPlainObject(value) && isPlainObject(target[key])) {
      Object.assign(target[key], value);
    } else {
      target[key] = value;
    }
  }
}

function containsWorkmuxStatusCommand(value) {
  if (typeof value === "string") return value.includes("workmux set-window-status");
  if (Array.isArray(value)) return value.some(containsWorkmuxStatusCommand);
  if (value && typeof value === "object") return Object.values(value).some(containsWorkmuxStatusCommand);
  return false;
}

let extraSettings = {};
try {
  if (process.env.EXTRA_SETTINGS) extraSettings = JSON.parse(process.env.EXTRA_SETTINGS);
} catch (e) {
  console.error("agents: invalid EXTRA_SETTINGS JSON — ignoring: " + e.message);
}

const sourceHooks = readJson(sourceFile, null);
const target = readJson(targetFile, {});
if (!sourceHooks) process.exit(0);

const hooks = target.hooks && typeof target.hooks === "object" && !Array.isArray(target.hooks)
  ? target.hooks
  : {};

for (const [eventName, desiredEntries] of Object.entries(sourceHooks)) {
  const existingEntries = Array.isArray(hooks[eventName]) ? hooks[eventName] : [];
  hooks[eventName] = [
    ...existingEntries.filter((entry) => !containsWorkmuxStatusCommand(entry)),
    ...desiredEntries,
  ];
}

target.hooks = hooks;

if (extraSettings && typeof extraSettings === "object") {
  mergeSettingsInto(target, extraSettings);
}

writeJsonIfChanged(targetFile, target);
