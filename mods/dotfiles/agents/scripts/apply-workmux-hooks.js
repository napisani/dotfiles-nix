// Merges Workmux window-status hooks into Claude Code and Codex config files.
// Non-destructive: replaces only managed workmux entries, preserving user-added hooks.
//
// Input (env vars):
//   DOTFILES        — absolute path to the mods/dotfiles directory
//   HOME            — home directory
//   CLAUDE_SETTINGS — optional JSON object of settings to always merge into ~/.claude/settings.json

const fs = require("node:fs");
const path = require("node:path");

const home = process.env.HOME;
const dotfiles = process.env.DOTFILES;
const sourceDir = path.join(dotfiles, "agents", "workmux-status");

function readJson(file, fallback) {
  try {
    if (!fs.existsSync(file)) return fallback;
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    // Repair: rename the corrupted file and continue with the fallback so that
    // the managed hooks and settings are still applied to a fresh, valid file.
    const backup = file + ".corrupted";
    try { fs.renameSync(file, backup); } catch {}
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
  console.log("agents: applied Workmux status hooks -> " + file);
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

function mergeHookMap(targetFile, sourceFile, extraSettings) {
  const sourceHooks = readJson(sourceFile, null);
  // readJson now always returns an object on error (fallback {}), so target is never null.
  const target = readJson(targetFile, {});
  if (!sourceHooks) return;

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
}

function mergeCodexHooks(targetFile, sourceFile) {
  const source = readJson(sourceFile, null);
  const target = readJson(targetFile, {});
  if (!source || !target) return;

  const hooks = target.hooks && typeof target.hooks === "object" && !Array.isArray(target.hooks)
    ? target.hooks
    : {};

  for (const [eventName, desiredEntries] of Object.entries(source)) {
    const existingEntries = Array.isArray(hooks[eventName]) ? hooks[eventName] : [];
    hooks[eventName] = [
      ...existingEntries.filter((entry) => !containsWorkmuxStatusCommand(entry)),
      ...desiredEntries,
    ];
  }

  target.hooks = hooks;
  writeJsonIfChanged(targetFile, target);
}

function codexEventKey(eventName) {
  return eventName.replace(/([a-z0-9])([A-Z])/g, "$1_$2").toLowerCase();
}

function codexWorkmuxHookKeys(hooksFile) {
  const config = readJson(hooksFile, null);
  const hooks = config && config.hooks && typeof config.hooks === "object" && !Array.isArray(config.hooks)
    ? config.hooks
    : {};
  const keys = [];

  for (const [eventName, groups] of Object.entries(hooks)) {
    if (!Array.isArray(groups)) continue;
    groups.forEach((group, groupIndex) => {
      const handlers = group && Array.isArray(group.hooks) ? group.hooks : [];
      handlers.forEach((handler, handlerIndex) => {
        if (containsWorkmuxStatusCommand(handler)) {
          keys.push(hooksFile + ":" + codexEventKey(eventName) + ":" + groupIndex + ":" + handlerIndex);
        }
      });
    });
  }

  return keys;
}

function tomlSection(lines, header) {
  const start = lines.findIndex((line) => line.trim() === header);
  if (start === -1) return null;

  let end = lines.length;
  for (let index = start + 1; index < lines.length; index += 1) {
    if (/^\s*\[[^\n]+\]\s*$/.test(lines[index])) {
      end = index;
      break;
    }
  }

  return { start, end };
}

function ensureCodexHooksEnabled(configFile, hooksFile) {
  const original = fs.existsSync(configFile) ? fs.readFileSync(configFile, "utf8") : "";
  const lines = original.trim() ? original.replace(/\n+$/, "").split("\n") : [];

  const featuresHeader = "[features]";
  const features = tomlSection(lines, featuresHeader);
  if (features) {
    let foundHooksFlag = false;
    for (let index = features.start + 1; index < features.end; index += 1) {
      if (/^\s*hooks\s*=/.test(lines[index])) {
        foundHooksFlag = true;
        if (!/^\s*hooks\s*=\s*true\s*(#.*)?$/.test(lines[index])) {
          lines[index] = "hooks = true";
        }
      }
    }
    if (!foundHooksFlag) {
      lines.splice(features.start + 1, 0, "hooks = true");
    }
  } else {
    if (lines.length && lines[lines.length - 1] !== "") lines.push("");
    lines.push(featuresHeader, "hooks = true");
  }

  for (const key of codexWorkmuxHookKeys(hooksFile)) {
    const header = "[hooks.state." + JSON.stringify(key) + "]";
    const section = tomlSection(lines, header);
    if (!section) continue;

    for (let index = section.start + 1; index < section.end; index += 1) {
      if (/^\s*enabled\s*=\s*false\s*(#.*)?$/.test(lines[index])) {
        lines[index] = "enabled = true";
      }
    }
  }

  const next = lines.join("\n") + "\n";
  if (next !== original) {
    fs.mkdirSync(path.dirname(configFile), { recursive: true });
    fs.writeFileSync(configFile, next);
    console.log("agents: ensured Codex Workmux hooks are enabled -> " + configFile);
  }
}

const codexHooksFile = path.join(home, ".codex", "hooks.json");

let claudeSettings = {};
try {
  if (process.env.CLAUDE_SETTINGS) claudeSettings = JSON.parse(process.env.CLAUDE_SETTINGS);
} catch (e) {
  console.error("agents: invalid CLAUDE_SETTINGS JSON — ignoring: " + e.message);
}

mergeHookMap(path.join(home, ".claude", "settings.json"), path.join(sourceDir, "claude-hooks.json"), claudeSettings);
mergeCodexHooks(codexHooksFile, path.join(sourceDir, "codex-hooks.json"));
ensureCodexHooksEnabled(path.join(home, ".codex", "config.toml"), codexHooksFile);
