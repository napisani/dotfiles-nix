const PROVIDER = "claude-bridge";
const THINKING_LEVELS = new Set([
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
]);

function readOption(argv, name) {
  const flag = `--${name}`;
  for (let index = 2; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === flag) {
      return argv[index + 1];
    }
    if (typeof argument === "string" && argument.startsWith(`${flag}=`)) {
      return argument.slice(flag.length + 1);
    }
  }
  return undefined;
}

function splitThinkingLevel(model, explicitThinking) {
  let modelId = model;
  let suffix;
  const colon = model.lastIndexOf(":");
  if (colon !== -1) {
    const candidate = model.slice(colon + 1).toLowerCase();
    if (THINKING_LEVELS.has(candidate)) {
      modelId = model.slice(0, colon);
      suffix = candidate;
    }
  }

  const normalizedExplicit = typeof explicitThinking === "string"
    ? explicitThinking.toLowerCase()
    : undefined;
  const thinkingLevel =
    normalizedExplicit && THINKING_LEVELS.has(normalizedExplicit)
      ? normalizedExplicit
      : suffix;

  return { modelId, thinkingLevel };
}

function parseRequestedBridgeModel(argv = process.argv) {
  const provider = readOption(argv, "provider");
  const model = readOption(argv, "model");
  if (!model) {
    return undefined;
  }

  const normalizedProvider = provider && provider.toLowerCase();
  const prefix = `${PROVIDER}/`;
  const qualified = model.toLowerCase().startsWith(prefix);

  if (normalizedProvider && normalizedProvider !== PROVIDER) {
    return undefined;
  }
  if (!normalizedProvider && !qualified) {
    return undefined;
  }

  const unqualifiedModel = qualified ? model.slice(prefix.length) : model;
  return splitThinkingLevel(
    unqualifiedModel,
    readOption(argv, "thinking"),
  );
}

function fail(ctx, message, exitProcess, logError) {
  if (ctx && ctx.ui && typeof ctx.ui.notify === "function") {
    ctx.ui.notify(message, "error");
  }
  logError(message);
  exitProcess(1);
  // Test doubles return from exitProcess; the real process.exit does not.
  throw new Error(message);
}

function claudeBridgeCliModel(api, options = {}) {
  const requested = parseRequestedBridgeModel(options.argv || process.argv);
  const exitProcess = options.exitProcess || process.exit;
  const logError = options.logError || console.error;
  let discoveryApplied = false;
  let preflightApplied = false;

  async function applyRequestedModel(ctx, required) {
    if (!requested) {
      return false;
    }

    const registry = ctx && ctx.modelRegistry;
    const model = registry && typeof registry.find === "function"
      ? registry.find(PROVIDER, requested.modelId)
      : undefined;
    if (!model) {
      if (required) {
        fail(
          ctx,
          `claude-bridge CLI model was not registered: ${requested.modelId}`,
          exitProcess,
          logError,
        );
      }
      return false;
    }

    const selected = await api.setModel(model);
    if (!selected) {
      if (required) {
        fail(
          ctx,
          `claude-bridge CLI model is unavailable: ${requested.modelId}`,
          exitProcess,
          logError,
        );
      }
      return false;
    }

    if (requested.thinkingLevel) {
      api.setThinkingLevel(requested.thinkingLevel);
    }
    return true;
  }

  // pi-claude-bridge can defer provider registration until session_start when
  // its module is loaded more than once. resources_discover runs after that
  // registration decision. Reassert once at the final pre-request barrier
  // because Pi can restore its prematurely resolved fallback after earlier
  // startup handlers have run.
  api.on("resources_discover", async (_event, ctx) => {
    if (!discoveryApplied) {
      discoveryApplied = await applyRequestedModel(ctx, false);
    }
  });
  api.on("before_agent_start", async (_event, ctx) => {
    if (!preflightApplied) {
      preflightApplied = await applyRequestedModel(ctx, true);
    }
  });
}

module.exports = claudeBridgeCliModel;
module.exports.parseRequestedBridgeModel = parseRequestedBridgeModel;
module.exports.readOption = readOption;
module.exports.splitThinkingLevel = splitThinkingLevel;
