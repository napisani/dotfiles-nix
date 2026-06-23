// Applies managed Pi agent settings to ~/.pi/agent/settings.json.
// Non-destructive: merges only the managed keys/entries, preserving user config.

const fs = require("node:fs");
const path = require("node:path");

const settingsPath = path.join(process.env.HOME, ".pi", "agent", "settings.json");

let settings = {};
if (fs.existsSync(settingsPath)) {
  try {
    settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
  } catch (error) {
    console.error("agents: refusing to update invalid Pi settings JSON at " + settingsPath + ": " + error.message);
    process.exit(0);
  }
}

const managed = {
  defaultProvider: "openai-codex",
  defaultModel: "gpt-5.5",
  defaultThinkingLevel: "xhigh",
  theme: "kanagawa",
};
const managedSkills = [
  "~/code/*/apps/*/.agents/skills",
];
const managedPackages = [
  "npm:@ayulab/pi-rewind",
  "npm:pi-mcp-adapter",
];
const removedPackages = new Set([
  "npm:pi-subagents",
]);

let changed = false;
for (const [key, value] of Object.entries(managed)) {
  if (settings[key] !== value) {
    settings[key] = value;
    changed = true;
  }
}

const currentOpenAI = settings.openaiReasoningMode && typeof settings.openaiReasoningMode === "object"
  ? settings.openaiReasoningMode
  : {};
if (currentOpenAI.fast !== true) {
  settings.openaiReasoningMode = { ...currentOpenAI, fast: true };
  changed = true;
}

const currentPackages = Array.isArray(settings.packages) ? settings.packages : [];
const nextPackages = currentPackages.filter((pkg) => !removedPackages.has(pkg));
let packagesChanged = !Array.isArray(settings.packages) || nextPackages.length !== currentPackages.length;
for (const pkg of managedPackages) {
  if (!nextPackages.includes(pkg)) {
    nextPackages.push(pkg);
    packagesChanged = true;
  }
}
if (packagesChanged) {
  settings.packages = nextPackages;
  changed = true;
}

const currentSkills = Array.isArray(settings.skills) ? settings.skills : [];
const nextSkills = [...currentSkills];
let skillsChanged = !Array.isArray(settings.skills);
for (const skillPath of managedSkills) {
  if (!nextSkills.includes(skillPath)) {
    nextSkills.push(skillPath);
    skillsChanged = true;
  }
}
if (skillsChanged) {
  settings.skills = nextSkills;
  changed = true;
}

if (changed) {
  fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
  console.log("agents: applied Pi defaults -> openai-codex/gpt-5.5/xhigh, fast:on, theme:kanagawa, monorepo app skills, managed Pi packages");
}
