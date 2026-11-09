const assert = require("node:assert/strict");
const test = require("node:test");

const remotePiAskTextAnswer = require("./remote-pi-ask-text-answer.js");

const COLOR = {
  id: "color",
  prompt: "Pick a color",
  type: "single",
  options: [
    { value: "red", label: "Red" },
    { value: "blue", label: "Blue" },
  ],
};
const TOPPINGS = {
  id: "toppings",
  prompt: "Pick toppings",
  type: "multi",
  options: [
    { value: "cheese", label: "Extra cheese" },
    { value: "ham", label: "Ham" },
    { value: "olives", label: "Olives" },
  ],
};

// Synchronous bus like Pi's, with a pi-ask stand-in that answers submits.
function makeHarness({ piAskReply } = {}) {
  const listeners = new Map();
  const handlers = new Map();
  const notices = [];
  const submits = [];
  const events = {
    on(channel, handler) {
      listeners.set(channel, [...(listeners.get(channel) ?? []), handler]);
    },
    emit(channel, data) {
      for (const handler of listeners.get(channel) ?? []) {
        handler(data);
      }
    },
  };
  events.on("@eko24ive/pi-ask:submit", (event) => {
    submits.push(event);
    const reply = piAskReply ? piAskReply(event) : { ok: true };
    if (reply) {
      events.emit("@eko24ive/pi-ask:submit-result", {
        version: 1,
        requestId: event.requestId,
        flowId: event.flowId,
        ...reply,
      });
    }
  });
  remotePiAskTextAnswer({
    events,
    on(name, handler) {
      handlers.set(name, handler);
    },
  });
  const ctx = { ui: { notify: (message, level) => notices.push({ message, level }) } };
  return {
    notices,
    submits,
    startFlow(questions, flowId = "tool:1") {
      events.emit("@eko24ive/pi-ask:started", { version: 1, flowId, questions });
    },
    completeFlow(flowId = "tool:1") {
      events.emit("@eko24ive/pi-ask:completed", { version: 1, flowId });
    },
    shutdown: () => handlers.get("session_shutdown")(),
    input: (text, source = "extension") =>
      handlers.get("input")({ type: "input", text, source }, ctx),
  };
}

test("an option number answers a single question", () => {
  const h = makeHarness();
  h.startFlow([COLOR]);
  assert.deepEqual(h.input("2"), {
    action: "transform",
    text: "(ask_user answered from phone: 2)",
  });
  assert.equal(h.submits.length, 1);
  assert.equal(h.submits[0].flowId, "tool:1");
  assert.deepEqual(h.submits[0].response, {
    kind: "answer",
    answers: { color: { values: ["blue"] } },
  });
});

test("a label or value answers regardless of case", () => {
  const h = makeHarness();
  h.startFlow([COLOR]);
  h.input("  rEd ");
  assert.deepEqual(h.submits[0].response.answers, { color: { values: ["red"] } });
});

test("unmatched text becomes a custom answer", () => {
  const h = makeHarness();
  h.startFlow([COLOR]);
  h.input("green, please\nthe dark one");
  assert.deepEqual(h.submits[0].response.answers, {
    color: { customText: "green, please\nthe dark one" },
  });
});

test("a number past the last option is custom text", () => {
  const h = makeHarness();
  h.startFlow([COLOR]);
  h.input("7");
  assert.deepEqual(h.submits[0].response.answers, { color: { customText: "7" } });
});

test("multi questions accept numbers and labels as lists", () => {
  for (const reply of ["1,3", "1 3", "extra cheese, olives", "3, 1, 1"]) {
    const h = makeHarness();
    h.startFlow([TOPPINGS]);
    h.input(reply);
    assert.deepEqual(
      [...h.submits[0].response.answers.toppings.values].sort(),
      ["cheese", "olives"],
      reply,
    );
  }
});

test("a multi list with an unknown item is custom text", () => {
  const h = makeHarness();
  h.startFlow([TOPPINGS]);
  h.input("1, pineapple");
  assert.deepEqual(h.submits[0].response.answers, {
    toppings: { customText: "1, pineapple" },
  });
});

test("several questions take one line each, in order", () => {
  const h = makeHarness();
  h.startFlow([COLOR, TOPPINGS]);
  h.input("1\n2,3");
  assert.deepEqual(h.submits[0].response.answers, {
    color: { values: ["red"] },
    toppings: { values: ["ham", "olives"] },
  });
});

test("a line count mismatch is left for the agent and warns", () => {
  const h = makeHarness();
  h.startFlow([COLOR, TOPPINGS]);
  assert.equal(h.input("1"), undefined);
  assert.equal(h.submits.length, 0);
  assert.equal(h.notices[0].level, "warning");
});

test("cancel cancels the flow unless it is an option", () => {
  const h = makeHarness();
  h.startFlow([COLOR]);
  assert.equal(h.input("Cancel").action, "transform");
  assert.deepEqual(h.submits[0].response, { kind: "cancel" });

  const optionNamed = makeHarness();
  optionNamed.startFlow([
    { ...COLOR, options: [{ value: "cancel", label: "Cancel" }] },
  ]);
  optionNamed.input("cancel");
  assert.deepEqual(optionNamed.submits[0].response.answers, {
    color: { values: ["cancel"] },
  });
});

test("desktop input and idle sessions are untouched", () => {
  const h = makeHarness();
  assert.equal(h.input("2"), undefined);
  h.startFlow([COLOR]);
  assert.equal(h.input("2", "interactive"), undefined);
  assert.equal(h.submits.length, 0);
});

test("a completed or shut down flow no longer captures input", () => {
  const h = makeHarness();
  h.startFlow([COLOR]);
  h.completeFlow();
  assert.equal(h.input("1"), undefined);

  h.startFlow([COLOR], "tool:2");
  h.shutdown();
  assert.equal(h.input("1"), undefined);
  assert.equal(h.submits.length, 0);
});

test("a rejected answer falls through and surfaces pi-ask's message", () => {
  const h = makeHarness({
    piAskReply: () => ({ ok: false, error: "invalid_answer", message: "nope" }),
  });
  h.startFlow([COLOR]);
  assert.equal(h.input("1"), undefined);
  assert.match(h.notices[0].message, /nope/);
});

test("no pi-ask response falls through", () => {
  const h = makeHarness({ piAskReply: () => undefined });
  h.startFlow([COLOR]);
  assert.equal(h.input("1"), undefined);
});
