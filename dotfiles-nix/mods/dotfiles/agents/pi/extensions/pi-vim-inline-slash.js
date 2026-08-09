const EDITOR_PATCHED = Symbol.for("dotfiles.pi.piVimInlineSlash.editorPatched");
const FACTORY_WRAPPED = Symbol.for("dotfiles.pi.piVimInlineSlash.factoryWrapped");
const UI_WRAPPED = Symbol.for("dotfiles.pi.piVimInlineSlash.uiWrapped");

const SUPPORTED_SOURCES = new Set(["extension", "prompt", "skill"]);
const SKILL_PREFIX = "skill:";

function isRecord(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function normalizeCommandName(name) {
  return name.trim().replace(/^\/+/, "");
}

function buildMatchKeys(name, source) {
  const keys = new Set([name.toLowerCase()]);

  if (source === "skill" && name.toLowerCase().startsWith(SKILL_PREFIX)) {
    const shortAlias = name.slice(SKILL_PREFIX.length).trim().toLowerCase();
    if (shortAlias) {
      keys.add(shortAlias);
    }
  }

  return [...keys];
}

function toCatalogEntry(command) {
  if (!isRecord(command) || !isNonEmptyString(command.name) || !SUPPORTED_SOURCES.has(command.source)) {
    return null;
  }

  const name = normalizeCommandName(command.name);
  if (!name || /\s/.test(name)) {
    return null;
  }

  return {
    name,
    queryKey: name.toLowerCase(),
    matchKeys: buildMatchKeys(name, command.source),
    label: `/${name}`,
    insertText: `/${name}`,
    description: isNonEmptyString(command.description) ? command.description.trim() : undefined,
  };
}

function buildCommandCatalog(commands) {
  const entries = [];
  const seen = new Set();

  for (const command of Array.isArray(commands) ? commands : []) {
    const entry = toCatalogEntry(command);
    if (!entry || seen.has(entry.queryKey)) {
      continue;
    }

    seen.add(entry.queryKey);
    entries.push(entry);
  }

  entries.sort((left, right) => left.queryKey.localeCompare(right.queryKey));
  return entries;
}

function joinLines(lines) {
  return lines.join("\n");
}

function splitLines(text) {
  return text.split("\n");
}

function cursorToOffset(lines, cursorLine, cursorCol) {
  if (!Array.isArray(lines) || cursorLine < 0 || cursorLine >= lines.length || cursorCol < 0) {
    return null;
  }

  const line = lines[cursorLine] || "";
  if (cursorCol > line.length) {
    return null;
  }

  let offset = cursorCol;
  for (let index = 0; index < cursorLine; index += 1) {
    offset += (lines[index] || "").length + 1;
  }

  return offset;
}

function offsetToCursor(text, offset) {
  const beforeCursor = text.slice(0, Math.max(0, Math.min(offset, text.length)));
  const lines = beforeCursor.split("\n");
  return { cursorLine: lines.length - 1, cursorCol: lines.at(-1).length };
}

function isWhitespace(char) {
  return /\s/.test(char || "");
}

function getProbeIndex(text, cursor) {
  if (cursor === text.length) {
    return cursor > 0 ? cursor - 1 : null;
  }
  if (cursor < 0 || cursor >= text.length) {
    return null;
  }
  if (isWhitespace(text[cursor])) {
    return cursor > 0 && !isWhitespace(text[cursor - 1]) ? cursor - 1 : null;
  }
  return cursor;
}

function analyzeSlashToken(text, cursor) {
  if (!text) {
    return null;
  }

  const probeIndex = getProbeIndex(text, cursor);
  if (probeIndex === null) {
    return null;
  }

  let start = probeIndex;
  while (start > 0 && !isWhitespace(text[start - 1])) {
    start -= 1;
  }

  let end = probeIndex;
  while (end < text.length && !isWhitespace(text[end])) {
    end += 1;
  }

  const token = text.slice(start, end);
  if (!token.startsWith("/")) {
    return null;
  }

  if (token.slice(1).includes("/")) {
    return null;
  }

  if (token !== "/" && !/^\/(skill:[a-z0-9._-]*|[a-z][a-z0-9-]*)$/i.test(token)) {
    return null;
  }

  return { token, query: token.slice(1).toLowerCase(), start, end };
}

function isStartOfMessageSlash(lines, cursorLine, cursorCol) {
  return cursorLine === 0 && (lines[0] || "").slice(0, cursorCol).startsWith("/");
}

function hasSuggestionItems(suggestions) {
  return isRecord(suggestions) && Array.isArray(suggestions.items) && suggestions.items.length > 0;
}

class InlineSlashProvider {
  constructor(catalog, delegate) {
    this.catalog = catalog;
    this.delegate = delegate || null;
  }

  analyze(lines, cursorLine, cursorCol) {
    const offset = cursorToOffset(lines, cursorLine, cursorCol);
    if (offset === null) {
      return null;
    }

    return analyzeSlashToken(joinLines(lines), offset);
  }

  async getSuggestions(lines, cursorLine, cursorCol, options = {}) {
    if (isStartOfMessageSlash(lines, cursorLine, cursorCol)) {
      return this.delegate && typeof this.delegate.getSuggestions === "function"
        ? this.delegate.getSuggestions(lines, cursorLine, cursorCol, options)
        : null;
    }

    const analysis = this.analyze(lines, cursorLine, cursorCol);
    if (!analysis) {
      return this.delegate && typeof this.delegate.getSuggestions === "function"
        ? this.delegate.getSuggestions(lines, cursorLine, cursorCol, options)
        : null;
    }

    if (this.delegate && typeof this.delegate.getSuggestions === "function") {
      const delegated = await this.delegate.getSuggestions(
        [analysis.token],
        0,
        analysis.token.length,
        options,
      );
      if (hasSuggestionItems(delegated)) {
        return { ...delegated, prefix: analysis.token };
      }
    }

    const items = this.catalog
      .filter((entry) => entry.matchKeys.some((key) => key.startsWith(analysis.query)))
      .map((entry) => ({
        value: entry.insertText,
        label: entry.label,
        ...(entry.description ? { description: entry.description } : {}),
      }));

    return items.length > 0 ? { items, prefix: analysis.token } : null;
  }

  applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
    if (isStartOfMessageSlash(lines, cursorLine, cursorCol)) {
      return this.delegate && typeof this.delegate.applyCompletion === "function"
        ? this.delegate.applyCompletion(lines, cursorLine, cursorCol, item, prefix)
        : { lines, cursorLine, cursorCol };
    }

    const offset = cursorToOffset(lines, cursorLine, cursorCol);
    const analysis = offset === null ? null : analyzeSlashToken(joinLines(lines), offset);

    if (!analysis) {
      return this.delegate && typeof this.delegate.applyCompletion === "function"
        ? this.delegate.applyCompletion(lines, cursorLine, cursorCol, item, prefix)
        : { lines, cursorLine, cursorCol };
    }

    const text = joinLines(lines);
    const insertText = String(item && (item.value || item.label) || "").trim().replace(/^\/*/, "/");
    const afterToken = text.slice(analysis.end);
    const suffix = afterToken.length === 0 ? " " : "";
    const updatedText = `${text.slice(0, analysis.start)}${insertText}${suffix}${afterToken}`;
    const cursor = offsetToCursor(updatedText, analysis.start + insertText.length + suffix.length);

    return {
      lines: splitLines(updatedText),
      cursorLine: cursor.cursorLine,
      cursorCol: cursor.cursorCol,
    };
  }
}

function readEditorSnapshot(editor) {
  if (!editor || typeof editor.getText !== "function" || typeof editor.getLines !== "function" || typeof editor.getCursor !== "function") {
    return null;
  }

  const cursor = editor.getCursor();
  return {
    text: editor.getText(),
    lines: editor.getLines(),
    cursorLine: cursor.line,
    cursorCol: cursor.col,
  };
}

function didEditorSnapshotChange(before, after) {
  return !!before && !!after && (
    before.text !== after.text ||
    before.cursorLine !== after.cursorLine ||
    before.cursorCol !== after.cursorCol
  );
}

function getAutocompleteHooks(editor) {
  if (!editor || typeof editor.isShowingAutocomplete !== "function" || typeof editor.tryTriggerAutocomplete !== "function" || typeof editor.updateAutocomplete !== "function") {
    return null;
  }

  return {
    isShowingAutocomplete: editor.isShowingAutocomplete.bind(editor),
    tryTriggerAutocomplete: editor.tryTriggerAutocomplete.bind(editor),
    updateAutocomplete: editor.updateAutocomplete.bind(editor),
  };
}

function refreshInlineSlashAutocomplete(editor, provider) {
  const snapshot = readEditorSnapshot(editor);
  const hooks = getAutocompleteHooks(editor);
  if (!snapshot || !hooks || isStartOfMessageSlash(snapshot.lines, snapshot.cursorLine, snapshot.cursorCol)) {
    return;
  }

  const analysis = provider.analyze(snapshot.lines, snapshot.cursorLine, snapshot.cursorCol);
  if (!analysis) {
    return;
  }

  // Do not synchronously preflight suggestions here. Pi's real autocomplete
  // provider is async; triggering lets the core editor run its normal async
  // request pipeline and render the list when suggestions arrive.
  if (hooks.isShowingAutocomplete()) {
    hooks.updateAutocomplete();
  } else {
    hooks.tryTriggerAutocomplete(true);
  }
}

function patchEditor(editor, catalog) {
  if (!editor || editor[EDITOR_PATCHED]) {
    return editor;
  }

  let inlineProvider = null;

  if (typeof editor.setAutocompleteProvider === "function") {
    const originalSetAutocompleteProvider = editor.setAutocompleteProvider;
    editor.setAutocompleteProvider = function setInlineSlashAutocompleteProvider(provider) {
      inlineProvider = new InlineSlashProvider(catalog, provider);
      return originalSetAutocompleteProvider.call(this, inlineProvider);
    };
  }

  if (typeof editor.handleInput === "function") {
    const originalHandleInput = editor.handleInput;
    editor.handleInput = function handlePiVimInlineSlashInput(data) {
      const before = readEditorSnapshot(this);
      const result = originalHandleInput.call(this, data);
      const after = readEditorSnapshot(this);

      if (inlineProvider && didEditorSnapshotChange(before, after)) {
        refreshInlineSlashAutocomplete(this, inlineProvider);
      }

      return result;
    };
  }

  Object.defineProperty(editor, EDITOR_PATCHED, { value: true });
  return editor;
}

function wrapEditorFactory(factory, catalog) {
  if (typeof factory !== "function" || factory[FACTORY_WRAPPED]) {
    return factory;
  }

  const wrapped = function createPiVimInlineSlashEditor(tui, theme, keybindings) {
    return patchEditor(factory(tui, theme, keybindings), catalog);
  };

  Object.defineProperty(wrapped, FACTORY_WRAPPED, { value: true });
  return wrapped;
}

function patchEditorComponentRegistration(ui, catalog) {
  if (!ui || typeof ui.setEditorComponent !== "function" || ui[UI_WRAPPED]) {
    return;
  }

  const setEditorComponent = ui.setEditorComponent.bind(ui);

  ui.setEditorComponent = function setPiVimInlineSlashEditorComponent(factory) {
    return setEditorComponent(wrapEditorFactory(factory, catalog));
  };

  Object.defineProperty(ui, UI_WRAPPED, { value: true });

  if (typeof ui.getEditorComponent === "function") {
    const currentFactory = ui.getEditorComponent();
    if (typeof currentFactory === "function" && !currentFactory[FACTORY_WRAPPED]) {
      ui.setEditorComponent(currentFactory);
    }
  }
}

function piVimInlineSlash(api) {
  api.on("session_start", (_event, ctx) => {
    if (!ctx || !ctx.hasUI || !ctx.ui) {
      return;
    }

    patchEditorComponentRegistration(ctx.ui, buildCommandCatalog(api.getCommands && api.getCommands()));
  });
}

module.exports = piVimInlineSlash;
module.exports.InlineSlashProvider = InlineSlashProvider;
module.exports.analyzeSlashToken = analyzeSlashToken;
module.exports.buildCommandCatalog = buildCommandCatalog;
module.exports.patchEditor = patchEditor;
module.exports.patchEditorComponentRegistration = patchEditorComponentRegistration;
module.exports.refreshInlineSlashAutocomplete = refreshInlineSlashAutocomplete;
module.exports.wrapEditorFactory = wrapEditorFactory;
