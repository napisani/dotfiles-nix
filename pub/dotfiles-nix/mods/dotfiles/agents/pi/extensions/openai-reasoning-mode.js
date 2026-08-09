const fs = require("node:fs");
const path = require("node:path");

const SERVICE_TIER = "priority";
const THINKING_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh"];

function isRecord(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isOpenAICodexResponsesPayload(payload) {
  if (!isRecord(payload)) {
    return false;
  }

  const model = payload.model;
  if (typeof model === "string" && model.includes("codex")) {
    return true;
  }

  return (
    payload.stream === true &&
    typeof payload.instructions === "string" &&
    Array.isArray(payload.input) &&
    payload.tool_choice === "auto" &&
    "prompt_cache_key" in payload
  );
}

function notify(ctx, message, level = "info") {
  if (ctx && ctx.ui && typeof ctx.ui.notify === "function") {
    ctx.ui.notify(message, level);
  }
}

function normalizeArg(args) {
  return String(args || "").trim().toLowerCase();
}

function applyReasoningLevel(api, ctx, args) {
  const level = normalizeArg(args);

  if (!THINKING_LEVELS.includes(level)) {
    notify(
      ctx,
      `Usage: /reasoning ${THINKING_LEVELS.join("|")}`,
      "error",
    );
    return false;
  }

  api.setThinkingLevel(level);
  notify(ctx, `Reasoning level set to ${level}`, "info");
  return true;
}

function applyFastMode(state, ctx, args) {
  const value = normalizeArg(args);

  if (value !== "on" && value !== "off") {
    notify(ctx, "Usage: /fast on|off", "error");
    return false;
  }

  state.fastMode = value === "on";
  notify(ctx, `OpenAI Codex fast mode ${state.fastMode ? "enabled" : "disabled"}`, "info");
  return true;
}

function updateStatus(state, ctx) {
  if (!ctx || !ctx.ui || typeof ctx.ui.setStatus !== "function") {
    return;
  }

  ctx.ui.setStatus("openai-fast", state.fastMode ? "fast:on" : undefined);
}

function defaultSettingsPath() {
  return path.join(process.env.HOME || "", ".pi", "agent", "settings.json");
}

function readSettings(settingsPath = defaultSettingsPath()) {
  try {
    if (!settingsPath || !fs.existsSync(settingsPath)) {
      return {};
    }

    return JSON.parse(fs.readFileSync(settingsPath, "utf8"));
  } catch {
    return {};
  }
}

async function applyStartupDefaults(api, ctx, state, settings) {
  if (!isRecord(settings)) {
    updateStatus(state, ctx);
    return;
  }

  if (typeof settings.defaultProvider === "string" && typeof settings.defaultModel === "string") {
    const model = ctx && ctx.modelRegistry && typeof ctx.modelRegistry.find === "function"
      ? ctx.modelRegistry.find(settings.defaultProvider, settings.defaultModel)
      : undefined;

    if (model && typeof api.setModel === "function") {
      await api.setModel(model);
    }
  }

  if (typeof settings.defaultThinkingLevel === "string" && THINKING_LEVELS.includes(settings.defaultThinkingLevel)) {
    api.setThinkingLevel(settings.defaultThinkingLevel);
  }

  if (isRecord(settings.openaiReasoningMode) && typeof settings.openaiReasoningMode.fast === "boolean") {
    state.fastMode = settings.openaiReasoningMode.fast;
  }

  updateStatus(state, ctx);
}

function openaiReasoningMode(api, options = {}) {
  const state = { fastMode: false };
  const loadSettings = typeof options.readSettings === "function" ? options.readSettings : readSettings;

  api.registerCommand("reasoning", {
    description: "Set reasoning/thinking level: off, minimal, low, medium, high, xhigh",
    handler: async (args, ctx) => {
      applyReasoningLevel(api, ctx, args);
    },
  });

  api.registerCommand("fast", {
    description: "Toggle OpenAI Codex priority service tier: on or off",
    handler: async (args, ctx) => {
      if (applyFastMode(state, ctx, args)) {
        updateStatus(state, ctx);
      }
    },
  });

  api.on("before_provider_request", (event) => {
    if (!state.fastMode || !isOpenAICodexResponsesPayload(event.payload)) {
      return;
    }

    return {
      ...event.payload,
      service_tier: SERVICE_TIER,
    };
  });

  api.on("session_start", async (_event, ctx) => {
    await applyStartupDefaults(api, ctx, state, loadSettings());
  });
}

module.exports = openaiReasoningMode;
module.exports.THINKING_LEVELS = THINKING_LEVELS;
module.exports.applyFastMode = applyFastMode;
module.exports.applyReasoningLevel = applyReasoningLevel;
module.exports.applyStartupDefaults = applyStartupDefaults;
module.exports.isOpenAICodexResponsesPayload = isOpenAICodexResponsesPayload;
module.exports.readSettings = readSettings;
