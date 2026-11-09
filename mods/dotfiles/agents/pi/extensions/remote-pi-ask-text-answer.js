const STARTED = "@eko24ive/pi-ask:started";
const COMPLETED = "@eko24ive/pi-ask:completed";
const SUBMIT = "@eko24ive/pi-ask:submit";
const SUBMIT_RESULT = "@eko24ive/pi-ask:submit-result";

// remote-pi store builds before PR #64 cannot decode the extension_ui_request
// frame, so a phone-driven ask_user blocks with no way to answer. This lets a
// plain text reply from the phone answer the pending pi-ask flow instead.

function resolveOption(question, token) {
  const text = token.trim();
  if (/^\d+$/.test(text)) {
    return question.options[Number(text) - 1];
  }
  const lower = text.toLowerCase();
  return question.options.find(
    (option) =>
      option.label.toLowerCase() === lower ||
      option.value.toLowerCase() === lower,
  );
}

function selectedValues(question, text) {
  const whole = resolveOption(question, text);
  if (whole) {
    return [whole.value];
  }
  if (question.type !== "multi") {
    return undefined;
  }
  const tokens = /^[\d\s,]+$/.test(text) ? text.split(/[\s,]+/) : text.split(",");
  const options = tokens.map((token) => resolveOption(question, token));
  if (options.some((option) => !option)) {
    return undefined;
  }
  return [...new Set(options.map((option) => option.value))];
}

function answerFor(question, text) {
  const values = selectedValues(question, text);
  return values ? { values } : { customText: text };
}

function replyToResponse(questions, rawText) {
  const text = rawText.trim();
  if (!text) {
    return undefined;
  }
  if (
    /^cancel$/i.test(text) &&
    !questions.some((question) => resolveOption(question, text))
  ) {
    return { kind: "cancel" };
  }
  // A single question takes the whole reply, so custom text may span lines.
  const lines =
    questions.length === 1
      ? [text]
      : text
          .split(/\r?\n/)
          .map((line) => line.trim())
          .filter(Boolean);
  if (lines.length !== questions.length) {
    return undefined;
  }
  const answers = {};
  questions.forEach((question, index) => {
    answers[question.id] = answerFor(question, lines[index]);
  });
  return { kind: "answer", answers };
}

function remotePiAskTextAnswer(pi) {
  const pendingFlows = new Map();
  let requestSequence = 0;
  let awaitedRequestId;
  let awaitedResult;

  pi.events.on(STARTED, (event) => {
    pendingFlows.set(event.flowId, event.questions);
  });
  pi.events.on(COMPLETED, (event) => {
    pendingFlows.delete(event.flowId);
  });
  pi.events.on(SUBMIT_RESULT, (event) => {
    if (event.requestId === awaitedRequestId) {
      awaitedResult = event;
    }
  });
  // pi-ask drops its flows on shutdown without emitting `completed`.
  pi.on("session_shutdown", () => {
    pendingFlows.clear();
  });

  // pi-ask answers submit events synchronously, so the result is readable
  // right after emit. No result means pi-ask is not handling the flow.
  function submit(flowId, response) {
    requestSequence += 1;
    awaitedRequestId = `phone-text-${requestSequence}`;
    awaitedResult = undefined;
    pi.events.emit(SUBMIT, {
      version: 1,
      requestId: awaitedRequestId,
      flowId,
      response,
    });
    return awaitedResult;
  }

  pi.on("input", (event, ctx) => {
    // Desktop input cannot reach the agent while the ask form is open.
    if (event.source === "interactive") {
      return undefined;
    }
    const [flowId, questions] = pendingFlows.entries().next().value ?? [];
    if (!flowId) {
      return undefined;
    }
    const response = replyToResponse(questions, event.text);
    if (!response) {
      const expected =
        questions.length === 1
          ? "an option number, label or text"
          : `${questions.length} lines, one answer per question`;
      ctx.ui.notify(
        `ask_user is waiting: reply with ${expected}, or "cancel".`,
        "warning",
      );
      return undefined;
    }
    const result = submit(flowId, response);
    if (!result?.ok) {
      if (result) {
        ctx.ui.notify(`ask_user answer rejected: ${result.message}`, "warning");
      }
      return undefined;
    }
    const answered = event.text.trim();
    ctx.ui.notify(`Answered ask_user from phone: ${answered}`, "info");
    // Swallowing the reply would leave remote-pi's pending steer unconsumed and
    // the phone stuck on it; a transformed message is consumed after the tool.
    return { action: "transform", text: `(ask_user answered from phone: ${answered})` };
  });
}

module.exports = remotePiAskTextAnswer;
module.exports.replyToResponse = replyToResponse;
