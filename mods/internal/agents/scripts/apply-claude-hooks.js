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

const { readJsonObject: readJson, writeJsonIfChanged, replaceManagedHooks } =
  require("../../scripts/lib/managed-hooks.js");

const targetFile = process.env.TARGET_FILE;
const sourceFile = process.env.SOURCE_FILE;

// One-level-deep merge: nested plain objects (e.g. `permissions`) are merged
// key-by-key into any existing object at that key, instead of replacing it
// wholesale — so pushing `{ permissions: { defaultMode: "auto" } }` doesn't
// clobber a `permissions.allow`/`permissions.deny` list set up elsewhere.
function mergeSettingsInto(target, extraSettings) {
  for (const [key, value] of Object.entries(extraSettings)) {
    const isPlainObject = (v) =>
      v && typeof v === "object" && !Array.isArray(v);
    if (isPlainObject(value) && isPlainObject(target[key])) {
      Object.assign(target[key], value);
    } else {
      target[key] = value;
    }
  }
}

function containsManagedCommand(value) {
  if (typeof value === "string") {
    return value.includes("workmux set-window-status") ||
      /(?:^|\/)rtk hook claude(?:\s|$)/.test(value) ||
      value.includes("/rtk-rewrite.sh");
  }
  if (Array.isArray(value)) return value.some(containsManagedCommand);
  if (value && typeof value === "object") {
    return Object.values(value).some(containsManagedCommand);
  }
  return false;
}

let extraSettings = {};
try {
  if (process.env.EXTRA_SETTINGS) {
    extraSettings = JSON.parse(process.env.EXTRA_SETTINGS);
  }
} catch (e) {
  throw new Error("invalid EXTRA_SETTINGS JSON: " + e.message);
}

const sourceHooks = readJson(sourceFile, null);
const target = readJson(targetFile, {});
if (!sourceHooks) throw new Error(`missing declared hooks at ${sourceFile}`);
if (process.env.RTK_SOURCE_FILE) {
  const rtk = readJson(process.env.RTK_SOURCE_FILE);
  if (!rtk?.hooks) throw new Error("missing RTK hooks");
  for (const [event, entries] of Object.entries(rtk.hooks)) {
    sourceHooks[event] = [...(sourceHooks[event] || []), ...entries];
  }
}

const hooks = target.hooks && typeof target.hooks === "object" &&
    !Array.isArray(target.hooks)
  ? target.hooks
  : {};

target.hooks = replaceManagedHooks(hooks, sourceHooks, containsManagedCommand);

if (extraSettings && typeof extraSettings === "object") {
  mergeSettingsInto(target, extraSettings);
}

// These settings share one file: project the complete result, then write once.
// Unlike the overlay settings, this key is owned wholesale.
if (process.env.SKILL_OVERRIDES !== undefined) {
  const overrides = JSON.parse(process.env.SKILL_OVERRIDES);
  if (!overrides || typeof overrides !== 'object' || Array.isArray(overrides)) throw new Error('invalid SKILL_OVERRIDES');
  target.skillOverrides = overrides;
}
writeJsonIfChanged(targetFile, target);
