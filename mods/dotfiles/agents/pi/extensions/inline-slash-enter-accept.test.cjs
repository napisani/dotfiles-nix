const assert = require("node:assert/strict");
const test = require("node:test");

const inlineSlashEnterAccept = require("./inline-slash-enter-accept.js");
const {
  currentTokenAtCursor,
  patchEditor,
  wrapEditorComponentFactory,
} = require("./inline-slash-enter-accept.js");

const enterKeybindings = {
  matches(data, action) {
    return data === "\r" && action === "tui.select.confirm";
  },
};

function makeEditor({
  text = "please use /skill:test",
  cursorCol = text.length,
  showingAutocomplete = true,
} = {}) {
  const calls = [];

  return {
    calls,
    getLines() {
      return [text];
    },
    getCursor() {
      return { line: 0, col: cursorCol };
    },
    isShowingAutocomplete() {
      return showingAutocomplete;
    },
    handleInput(data) {
      calls.push(data);
    },
  };
}

test("currentTokenAtCursor returns the slash token under the cursor", () => {
  assert.equal(
    currentTokenAtCursor(["please use /skill:test"], 0, "please use /skill:test".length),
    "/skill:test",
  );
});

test("patched editor accepts slash autocomplete on Enter without submitting", () => {
  const editor = patchEditor(makeEditor(), enterKeybindings);

  editor.handleInput("\r");

  assert.deepEqual(editor.calls, ["\t"]);
});

test("patched editor leaves Enter alone when autocomplete is hidden", () => {
  const editor = patchEditor(
    makeEditor({ showingAutocomplete: false }),
    enterKeybindings,
  );

  editor.handleInput("\r");

  assert.deepEqual(editor.calls, ["\r"]);
});

test("patched editor leaves Enter alone for non-slash autocomplete", () => {
  const editor = patchEditor(
    makeEditor({ text: "attach @README.md" }),
    enterKeybindings,
  );

  editor.handleInput("\r");

  assert.deepEqual(editor.calls, ["\r"]);
});

test("wrapped editor factories patch editors created by later extensions", () => {
  const factory = () => makeEditor();
  const wrappedFactory = wrapEditorComponentFactory(factory);

  const editor = wrappedFactory({}, {}, enterKeybindings);
  editor.handleInput("\r");

  assert.deepEqual(editor.calls, ["\t"]);
});

test("extension patches editor factories registered after session_start", async () => {
  const handlers = [];
  const api = {
    on(event, handler) {
      assert.equal(event, "session_start");
      handlers.push(handler);
    },
  };
  let activeFactory;
  const ctx = {
    hasUI: true,
    ui: {
      setEditorComponent(factory) {
        activeFactory = factory;
      },
      getEditorComponent() {
        return activeFactory;
      },
    },
  };

  inlineSlashEnterAccept(api);
  assert.equal(handlers.length, 1);

  await handlers[0]({ type: "session_start" }, ctx);
  ctx.ui.setEditorComponent(() => makeEditor());

  const editor = activeFactory({}, {}, enterKeybindings);
  editor.handleInput("\r");

  assert.deepEqual(editor.calls, ["\t"]);
});
