const assert = require("node:assert/strict");
const test = require("node:test");

const piVimInlineSlash = require("./pi-vim-inline-slash.js");
const {
  InlineSlashProvider,
  buildCommandCatalog,
  patchEditor,
  wrapEditorFactory,
} = require("./pi-vim-inline-slash.js");

function makeCommand(name, source = "extension") {
  return {
    name,
    source,
    description: `${name} description`,
    sourceInfo: { path: "/tmp/ext", source: "local", scope: "user", origin: "top-level" },
  };
}

function makeVimLikeEditor(text = "please /rea") {
  const autocompleteTriggers = [];
  const updates = [];
  let provider = null;
  let currentText = text;
  let cursorCol = text.length;
  let showingAutocomplete = false;

  return {
    autocompleteTriggers,
    updates,
    getText() {
      return currentText;
    },
    getLines() {
      return [currentText];
    },
    getCursor() {
      return { line: 0, col: cursorCol };
    },
    setAutocompleteProvider(nextProvider) {
      provider = nextProvider;
    },
    getAutocompleteProvider() {
      return provider;
    },
    isShowingAutocomplete() {
      return showingAutocomplete;
    },
    tryTriggerAutocomplete(explicitTab) {
      showingAutocomplete = true;
      autocompleteTriggers.push({ explicitTab, text: currentText });
    },
    updateAutocomplete() {
      updates.push(currentText);
    },
    handleInput(data) {
      if (data.length === 1 && data !== "\r" && data !== "\n" && data !== "\t") {
        currentText = `${currentText.slice(0, cursorCol)}${data}${currentText.slice(cursorCol)}`;
        cursorCol += data.length;
      }
    },
  };
}

test("buildCommandCatalog includes skill short aliases", () => {
  const catalog = buildCommandCatalog([makeCommand("skill:diagnose", "skill")]);

  assert.deepEqual(catalog[0].matchKeys, ["skill:diagnose", "diagnose"]);
});

test("InlineSlashProvider suggests commands for inline slash tokens", async () => {
  const provider = new InlineSlashProvider(
    buildCommandCatalog([makeCommand("reasoning"), makeCommand("skill:diagnose", "skill")]),
    null,
  );

  const suggestions = await provider.getSuggestions(["please /rea"], 0, "please /rea".length);

  assert.deepEqual(suggestions.items.map((item) => item.value), ["/reasoning"]);
  assert.equal(suggestions.prefix, "/rea");
});

test("InlineSlashProvider reuses the core slash provider for a bare inline slash", async () => {
  const delegateCalls = [];
  const provider = new InlineSlashProvider([], {
    async getSuggestions(lines, cursorLine, cursorCol) {
      delegateCalls.push({ lines, cursorLine, cursorCol });
      return {
        items: [{ value: "/skill:diagnose", label: "/skill:diagnose" }],
        prefix: "/",
      };
    },
  });

  const suggestions = await provider.getSuggestions(["please /"], 0, "please /".length);

  assert.deepEqual(delegateCalls, [{ lines: ["/"], cursorLine: 0, cursorCol: 1 }]);
  assert.deepEqual(suggestions.items.map((item) => item.value), ["/skill:diagnose"]);
  assert.equal(suggestions.prefix, "/");
});

test("InlineSlashProvider delegates start-of-message slash to core provider", async () => {
  const delegateCalls = [];
  const provider = new InlineSlashProvider(buildCommandCatalog([makeCommand("reasoning")]), {
    getSuggestions(lines, cursorLine, cursorCol) {
      delegateCalls.push({ lines, cursorLine, cursorCol });
      return { items: [{ value: "/core", label: "/core" }], prefix: "/" };
    },
  });

  const suggestions = await provider.getSuggestions(["/rea"], 0, 4);

  assert.equal(suggestions.items[0].value, "/core");
  assert.equal(delegateCalls.length, 1);
});

test("patched vim-like editor triggers inline slash after edits even with async core suggestions", async () => {
  const editor = patchEditor(
    makeVimLikeEditor("please /re"),
    buildCommandCatalog([makeCommand("reasoning")]),
  );

  editor.setAutocompleteProvider({
    async getSuggestions() {
      return { items: [{ value: "/reasoning", label: "/reasoning" }], prefix: "/rea" };
    },
  });
  editor.handleInput("a");

  assert.equal(editor.autocompleteTriggers.length, 1);
  assert.equal(editor.autocompleteTriggers[0].text, "please /rea");

  const suggestions = await editor.getAutocompleteProvider().getSuggestions(["please /rea"], 0, "please /rea".length);
  assert.equal(suggestions.items[0].value, "/reasoning");
});

test("wrapEditorFactory patches editors returned by pi-vim factory", () => {
  const factory = () => makeVimLikeEditor("please /re");
  const wrapped = wrapEditorFactory(factory, buildCommandCatalog([makeCommand("reasoning")]));

  const editor = wrapped({}, {}, {});
  editor.setAutocompleteProvider(null);
  editor.handleInput("a");

  assert.equal(editor.autocompleteTriggers.length, 1);
});

test("extension wraps the currently registered editor component", async () => {
  const handlers = [];
  const api = {
    on(event, handler) {
      assert.equal(event, "session_start");
      handlers.push(handler);
    },
    getCommands() {
      return [makeCommand("reasoning")];
    },
  };
  let activeFactory = () => makeVimLikeEditor("please /re");
  const ctx = {
    hasUI: true,
    ui: {
      getEditorComponent() {
        return activeFactory;
      },
      setEditorComponent(factory) {
        activeFactory = factory;
      },
    },
  };

  piVimInlineSlash(api);
  await handlers[0]({}, ctx);

  const editor = activeFactory({}, {}, {});
  editor.setAutocompleteProvider(null);
  editor.handleInput("a");

  assert.equal(editor.autocompleteTriggers.length, 1);
});

test("extension wraps editor components registered after session_start", async () => {
  const handlers = [];
  const api = {
    on(_event, handler) {
      handlers.push(handler);
    },
    getCommands() {
      return [makeCommand("reasoning")];
    },
  };
  let activeFactory;
  const ctx = {
    hasUI: true,
    ui: {
      getEditorComponent() {
        return activeFactory;
      },
      setEditorComponent(factory) {
        activeFactory = factory;
      },
    },
  };

  piVimInlineSlash(api);
  await handlers[0]({}, ctx);

  ctx.ui.setEditorComponent(() => makeVimLikeEditor("please /re"));
  const editor = activeFactory({}, {}, {});
  editor.setAutocompleteProvider(null);
  editor.handleInput("a");

  assert.equal(editor.autocompleteTriggers.length, 1);
});
