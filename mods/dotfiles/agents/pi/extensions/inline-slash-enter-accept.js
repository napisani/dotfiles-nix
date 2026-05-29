const EDITOR_PATCHED = Symbol.for("dotfiles.pi.inlineSlashEnterAccept.editorPatched");
const FACTORY_WRAPPED = Symbol.for("dotfiles.pi.inlineSlashEnterAccept.factoryWrapped");
const UI_WRAPPED = Symbol.for("dotfiles.pi.inlineSlashEnterAccept.uiWrapped");

function isWhitespace(value) {
  return value === undefined || /\s/.test(value);
}

function currentTokenAtCursor(lines, cursorLine, cursorCol) {
  if (!Array.isArray(lines) || !Number.isInteger(cursorLine)) {
    return "";
  }

  const line = lines[cursorLine];
  if (typeof line !== "string") {
    return "";
  }

  const col = Number.isInteger(cursorCol)
    ? Math.max(0, Math.min(cursorCol, line.length))
    : line.length;

  let start = col;
  while (start > 0 && !isWhitespace(line[start - 1])) {
    start -= 1;
  }

  let end = col;
  while (end < line.length && !isWhitespace(line[end])) {
    end += 1;
  }

  return line.slice(start, end);
}

function isConfirmInput(data, keybindings) {
  if (keybindings && typeof keybindings.matches === "function") {
    try {
      if (keybindings.matches(data, "tui.select.confirm")) {
        return true;
      }
    } catch {
      return false;
    }
  }

  return data === "\r" || data === "\n";
}

function isSlashAutocompleteContext(editor) {
  if (!editor || typeof editor.isShowingAutocomplete !== "function") {
    return false;
  }

  if (!editor.isShowingAutocomplete()) {
    return false;
  }

  if (typeof editor.getLines !== "function" || typeof editor.getCursor !== "function") {
    return false;
  }

  const cursor = editor.getCursor();
  const token = currentTokenAtCursor(
    editor.getLines(),
    cursor && cursor.line,
    cursor && cursor.col,
  );

  return token.startsWith("/");
}

function shouldAcceptSlashAutocompleteWithoutSubmit(editor, data, keybindings) {
  return isConfirmInput(data, keybindings) && isSlashAutocompleteContext(editor);
}

function patchEditor(editor, keybindings) {
  if (!editor || typeof editor.handleInput !== "function" || editor[EDITOR_PATCHED]) {
    return editor;
  }

  const originalHandleInput = editor.handleInput;

  editor.handleInput = function handleInlineSlashEnterAccept(data) {
    if (shouldAcceptSlashAutocompleteWithoutSubmit(this, data, keybindings)) {
      return originalHandleInput.call(this, "\t");
    }

    return originalHandleInput.call(this, data);
  };

  Object.defineProperty(editor, EDITOR_PATCHED, {
    value: true,
  });

  return editor;
}

function wrapEditorComponentFactory(factory) {
  if (typeof factory !== "function" || factory[FACTORY_WRAPPED]) {
    return factory;
  }

  const wrappedFactory = function createInlineSlashEnterAcceptEditor(
    tui,
    theme,
    keybindings,
  ) {
    return patchEditor(factory(tui, theme, keybindings), keybindings);
  };

  Object.defineProperty(wrappedFactory, FACTORY_WRAPPED, {
    value: true,
  });

  return wrappedFactory;
}

function patchEditorComponentRegistration(ui) {
  if (!ui || typeof ui.setEditorComponent !== "function" || ui[UI_WRAPPED]) {
    return;
  }

  const setEditorComponent = ui.setEditorComponent.bind(ui);

  ui.setEditorComponent = function setInlineSlashEnterAcceptEditorComponent(factory) {
    return setEditorComponent(wrapEditorComponentFactory(factory));
  };

  Object.defineProperty(ui, UI_WRAPPED, {
    value: true,
  });

  if (typeof ui.getEditorComponent === "function") {
    const currentFactory = ui.getEditorComponent();
    if (typeof currentFactory === "function" && !currentFactory[FACTORY_WRAPPED]) {
      ui.setEditorComponent(currentFactory);
    }
  }
}

function inlineSlashEnterAccept(api) {
  api.on("session_start", (_event, ctx) => {
    if (!ctx || !ctx.hasUI) {
      return;
    }

    patchEditorComponentRegistration(ctx.ui);
  });
}

module.exports = inlineSlashEnterAccept;
module.exports.currentTokenAtCursor = currentTokenAtCursor;
module.exports.isSlashAutocompleteContext = isSlashAutocompleteContext;
module.exports.shouldAcceptSlashAutocompleteWithoutSubmit =
  shouldAcceptSlashAutocompleteWithoutSubmit;
module.exports.patchEditor = patchEditor;
module.exports.wrapEditorComponentFactory = wrapEditorComponentFactory;
