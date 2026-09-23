const assert = require("node:assert/strict");
const test = require("node:test");

const {
  parseRequestedBridgeModel,
} = require("./claude-bridge-cli-model.js");
const claudeBridgeCliModel = require("./claude-bridge-cli-model.js");

function makeApi() {
  const events = new Map();
  const models = [];
  const thinkingLevels = [];

  return {
    events,
    models,
    thinkingLevels,
    on(event, handler) {
      events.set(event, handler);
    },
    async setModel(model) {
      models.push(model);
      return true;
    },
    setThinkingLevel(level) {
      thinkingLevels.push(level);
    },
  };
}

function makeCtx(available = true) {
  return {
    modelRegistry: {
      find(provider, model) {
        return available ? { provider, id: model } : undefined;
      },
    },
  };
}

test("parses separate claude-bridge provider and model flags", () => {
  assert.deepEqual(
    parseRequestedBridgeModel([
      "node",
      "pi",
      "--provider",
      "claude-bridge",
      "--model",
      "claude-sonnet-5",
    ]),
    { modelId: "claude-sonnet-5", thinkingLevel: undefined },
  );
});

test("parses equals-style flags", () => {
  assert.deepEqual(
    parseRequestedBridgeModel([
      "node",
      "pi",
      "--provider=claude-bridge",
      "--model=claude-sonnet-5",
      "--thinking=high",
    ]),
    { modelId: "claude-sonnet-5", thinkingLevel: "high" },
  );
});

test("parses a provider-qualified model and thinking suffix", () => {
  assert.deepEqual(
    parseRequestedBridgeModel([
      "node",
      "pi",
      "--model=claude-bridge/claude-sonnet-5:high",
    ]),
    { modelId: "claude-sonnet-5", thinkingLevel: "high" },
  );
});

test("explicit thinking overrides the model suffix", () => {
  assert.deepEqual(
    parseRequestedBridgeModel([
      "node",
      "pi",
      "--provider=claude-bridge",
      "--model=claude-sonnet-5:low",
      "--thinking=xhigh",
    ]),
    { modelId: "claude-sonnet-5", thinkingLevel: "xhigh" },
  );
});

test("ignores non-bridge model selections", () => {
  assert.equal(
    parseRequestedBridgeModel([
      "node",
      "pi",
      "--provider",
      "openai-codex",
      "--model",
      "gpt-5.6-luna",
    ]),
    undefined,
  );
});

test("retries at the final barrier when the bridge provider registers late", async () => {
  const api = makeApi();
  const argv = [
    "node",
    "pi",
    "--provider",
    "claude-bridge",
    "--model",
    "claude-sonnet-5",
    "--thinking",
    "high",
  ];
  let available = false;
  const ctx = {
    modelRegistry: {
      find(provider, model) {
        return available ? { provider, id: model } : undefined;
      },
    },
  };

  claudeBridgeCliModel(api, { argv });
  await api.events.get("resources_discover")({}, ctx);
  assert.deepEqual(api.models, []);

  available = true;
  await api.events.get("before_agent_start")({}, ctx);
  assert.deepEqual(api.models, [
    { provider: "claude-bridge", id: "claude-sonnet-5" },
  ]);
  assert.deepEqual(api.thinkingLevels, ["high"]);

  await api.events.get("before_agent_start")({}, ctx);
  assert.equal(
    api.models.length,
    1,
    "expected the preflight to apply only once",
  );
});

test("preflight reasserts a discovery-time selection exactly once", async () => {
  const api = makeApi();
  const ctx = makeCtx();
  claudeBridgeCliModel(api, {
    argv: [
      "node",
      "pi",
      "--provider",
      "claude-bridge",
      "--model",
      "claude-sonnet-5",
    ],
  });

  await api.events.get("resources_discover")({}, ctx);
  await api.events.get("before_agent_start")({}, ctx);
  await api.events.get("before_agent_start")({}, ctx);

  assert.equal(api.models.length, 2);
});

test("the final pre-request barrier terminates for an unavailable bridge model", async () => {
  const api = makeApi();
  api.setModel = async () => false;
  const exitCodes = [];
  claudeBridgeCliModel(api, {
    argv: [
      "node",
      "pi",
      "--model",
      "claude-bridge/claude-sonnet-5",
    ],
    exitProcess(code) {
      exitCodes.push(code);
    },
    logError() {},
  });

  await assert.rejects(
    api.events.get("before_agent_start")({}, makeCtx()),
    /model is unavailable: claude-sonnet-5/,
  );
  assert.deepEqual(exitCodes, [1]);
});

test("the final pre-request barrier terminates for a missing bridge model", async () => {
  const api = makeApi();
  const exitCodes = [];
  claudeBridgeCliModel(api, {
    argv: [
      "node",
      "pi",
      "--model",
      "claude-bridge/does-not-exist",
    ],
    exitProcess(code) {
      exitCodes.push(code);
    },
    logError() {},
  });

  await assert.rejects(
    api.events.get("before_agent_start")({}, makeCtx(false)),
    /model was not registered: does-not-exist/,
  );
  assert.deepEqual(exitCodes, [1]);
});
