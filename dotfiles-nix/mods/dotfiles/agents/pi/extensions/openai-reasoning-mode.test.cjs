const assert = require("node:assert/strict");
const test = require("node:test");

const openaiReasoningMode = require("./openai-reasoning-mode.js");
const {
  applyFastMode,
  applyReasoningLevel,
  applyStartupDefaults,
  isOpenAICodexResponsesPayload,
} = require("./openai-reasoning-mode.js");

function makeApi() {
  const commands = new Map();
  const events = new Map();
  const thinkingLevels = [];
  const models = [];

  return {
    commands,
    events,
    thinkingLevels,
    models,
    on(event, handler) {
      events.set(event, handler);
    },
    registerCommand(name, definition) {
      commands.set(name, definition);
    },
    setThinkingLevel(level) {
      thinkingLevels.push(level);
    },
    async setModel(model) {
      models.push(model);
      return true;
    },
  };
}

function makeCtx() {
  const notifications = [];
  const statuses = [];
  return {
    notifications,
    statuses,
    modelRegistry: {
      find(provider, model) {
        return { provider, id: model };
      },
    },
    ui: {
      notify(message, level) {
        notifications.push({ message, level });
      },
      setStatus(key, value) {
        statuses.push({ key, value });
      },
    },
  };
}

test("/reasoning sets a valid thinking level", async () => {
  const api = makeApi();
  const ctx = makeCtx();

  openaiReasoningMode(api);
  await api.commands.get("reasoning").handler("high", ctx);

  assert.deepEqual(api.thinkingLevels, ["high"]);
  assert.equal(ctx.notifications.at(-1).level, "info");
});

test("/reasoning rejects invalid thinking levels", async () => {
  const api = makeApi();
  const ctx = makeCtx();

  openaiReasoningMode(api);
  await api.commands.get("reasoning").handler("turbo", ctx);

  assert.deepEqual(api.thinkingLevels, []);
  assert.equal(ctx.notifications.at(-1).level, "error");
});

test("/fast on enables priority service tier for OpenAI Codex payloads", async () => {
  const api = makeApi();
  const ctx = makeCtx();

  openaiReasoningMode(api);
  await api.commands.get("fast").handler("on", ctx);

  const nextPayload = await api.events.get("before_provider_request")({
    payload: {
      model: "gpt-5-codex",
      stream: true,
      instructions: "do work",
      input: [],
      tool_choice: "auto",
      prompt_cache_key: "cache-key",
    },
  });

  assert.equal(nextPayload.service_tier, "priority");
});

test("/fast off stops adding priority service tier", async () => {
  const api = makeApi();
  const ctx = makeCtx();

  openaiReasoningMode(api);
  await api.commands.get("fast").handler("off", ctx);

  const result = await api.events.get("before_provider_request")({
    payload: {
      model: "gpt-5-codex",
      stream: true,
      instructions: "do work",
      input: [],
      tool_choice: "auto",
      prompt_cache_key: "cache-key",
    },
  });

  assert.equal(result, undefined);
});

test("startup defaults set model, thinking, and fast mode from settings", async () => {
  const api = makeApi();
  const ctx = makeCtx();
  const state = { fastMode: false };

  await applyStartupDefaults(api, ctx, state, {
    defaultProvider: "openai-codex",
    defaultModel: "gpt-5.5",
    defaultThinkingLevel: "xhigh",
    openaiReasoningMode: { fast: true },
  });

  assert.deepEqual(api.models, [{ provider: "openai-codex", id: "gpt-5.5" }]);
  assert.deepEqual(api.thinkingLevels, ["xhigh"]);
  assert.equal(state.fastMode, true);
  assert.deepEqual(ctx.statuses.at(-1), { key: "openai-fast", value: "fast:on" });
});

test("extension session_start applies fast mode from settings", async () => {
  const api = makeApi();
  const ctx = makeCtx();

  openaiReasoningMode(api, {
    readSettings: () => ({ openaiReasoningMode: { fast: true } }),
  });
  await api.events.get("session_start")({}, ctx);

  const nextPayload = await api.events.get("before_provider_request")({
    payload: {
      model: "gpt-5-codex",
      stream: true,
      instructions: "do work",
      input: [],
      tool_choice: "auto",
      prompt_cache_key: "cache-key",
    },
  });

  assert.equal(nextPayload.service_tier, "priority");
});

test("OpenAI Codex payload detection matches codex-shaped responses payloads", () => {
  assert.equal(
    isOpenAICodexResponsesPayload({
      stream: true,
      instructions: "do work",
      input: [],
      tool_choice: "auto",
      prompt_cache_key: "cache-key",
    }),
    true,
  );

  assert.equal(isOpenAICodexResponsesPayload({ model: "claude-sonnet-4-5" }), false);
});

test("helpers apply command state", () => {
  const api = makeApi();
  const ctx = makeCtx();
  const state = { fastMode: false };

  assert.equal(applyReasoningLevel(api, ctx, "minimal"), true);
  assert.deepEqual(api.thinkingLevels, ["minimal"]);

  assert.equal(applyFastMode(state, ctx, "on"), true);
  assert.equal(state.fastMode, true);
});
