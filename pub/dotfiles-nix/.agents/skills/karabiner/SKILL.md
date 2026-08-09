---
name: karabiner
description: Karabiner-Elements keyboard configuration using karabiner.ts TypeScript DSL. Use when modifying keyboard layers, shortcuts, modifier swaps, or window management keybindings. Covers simlayers, variable-based layers, and the rift-cli window manager integration.
---

# Karabiner Keyboard Configuration

## Quick Reference

| Item | Value |
|---|---|
| Location | `mods/dotfiles/karabiner/` |
| Runtime | Deno |
| Library | `karabiner.ts` v1.35.1 (npm, via Deno) |
| Build | `deno task build` (from `karabiner/` directory) |
| Output | `mods/dotfiles/karabiner.json` (one level up from source dir) |
| Reload | `karabiner-reload.sh` or restart Karabiner-Elements |
| Entry point | `src/index.ts` |

## Architecture

- Deno TypeScript project using `karabiner.ts` v1.35.1 via npm specifier
- `polyfill.ts` provides a CJS `require()` shim at the global scope (needed because karabiner.ts uses CommonJS internally)
- `src/index.ts` imports all rule modules, composes them, and calls `writeToProfile()` to generate the JSON config
- Output path: `~/.config/home-manager/mods/dotfiles/karabiner.json` (NOT inside the `karabiner/` directory)
- The build script also creates a symlink from `~/.config/karabiner/karabiner.json` -> the generated file
- Nix home-manager separately manages this symlink via `mkOutOfStoreSymlink`

### File Structure

```
mods/dotfiles/karabiner/
  polyfill.ts              # CJS require() shim
  deno.json                # Deno config, tasks, imports
  src/
    index.ts               # Entry point -- composes all rules
    cap-modifier.ts        # Caps Lock variable-based layer
    modifier-swap.ts       # Per-app Cmd/Ctrl/Fn swapping
    layers.ts              # Simlayers (a, d, l, n, s)
    window-layer.ts        # Tab dual-role for rift-cli window management
    leader-utils.ts        # exitLeader() helper
mods/dotfiles/karabiner.json  # Generated output (committed to repo)
```

## Active Modules (Priority Order)

Rules are passed to `writeToProfile()` in this order. Earlier rules take precedence.

### 1. cap-modifier.ts -- Caps Lock Variable-Based Layer

Uses the `"caps-layer"` variable. Caps Lock held = layer active; Caps Lock alone = Escape.

| Combo | Action |
|---|---|
| Caps + h/j/k/l | Arrow keys (left/down/up/right) |
| Caps + Space | Ctrl+Space (tmux prefix) |
| Caps + [a-z] (except hjkl) | Ctrl+[key] |
| Caps + quote | Ctrl+quote |
| Caps + 4 | Cmd+Shift+4 (screenshot selection) |
| Caps + 5 | Cmd+Shift+5 (screen record) |
| Caps alone | Escape (+ exitLeader) |

Implementation: Raw manipulator objects with `set_variable`/`variable_if` conditions on `"caps-layer"`.

### 2. modifier-swap.ts -- Per-App Cmd/Ctrl/Fn Swapping

Terminal apps (Terminal, iTerm2, Alacritty, Ghostty) are treated as "dev apps"; everything else is "standard apps".

| Context | Mapping |
|---|---|
| Standard apps | left_command <-> left_control (swapped) |
| Standard apps | fn -> left_command |
| Dev apps | fn -> left_control |

Uses `ifApp()` with regex bundle ID patterns and `.unless()` for negation.

### 3. layers.ts -- Simlayers

Uses `simlayer("key", "name")` from karabiner.ts. Hold the trigger key and press a second key simultaneously.

**`a` -- Delimiters/Brackets Layer:**

| Key | Output | Key | Output |
|---|---|---|---|
| r | `(` | u | `)` |
| f | `{` | j | `}` |
| d | `[` | k | `]` |
| t | `'` | y | `"` |
| g | `,` | h | `.` |
| c | `<` | m | `>` |
| v | `&` | n | `*` |

**`d` -- Arrows Layer:** h/j/k/l = left/down/up/right arrows

**`l` -- Operators/Symbols Layer:**

| Key | Output | Key | Output |
|---|---|---|---|
| r | `+` | u | `-` |
| t | `~` | i | `_` |
| f | `:` | j | `=` |
| g | `/` | h | `?` |
| c | `\` | m | `\|` |
| v | `!` | n | `%` |
| e | `$` | w | `^` |
| a | `@` | q | `0` |

**`n` -- Numbers Layer:** q=1, w=2, e=3, r=4, t=5, y=6, u=7, i=8, o=9, p=0

**`s` -- Control Layer:** h/j/k/l = Ctrl+h/j/k/l

### 4. window-layer.ts -- Tab Dual-Role for rift-cli Window Management

Uses two variables: `"tab_window_mode_active"` and `"tab_q_nested_mode_active"`. Tab held activates primary mode; Tab+Q held activates nested mode. Tab alone = Tab.

Calls `rift-cli` at `/etc/profiles/per-user/nick/bin/rift-cli` via `to$()` shell commands.

**Primary Mode (Tab held):**

| Key | Action |
|---|---|
| h/j/k/l | Focus window left/down/up/right |
| n/p | Workspace next/prev |
| q (hold) | Enter nested mode |

**Nested Mode (Tab+Q held):**

| Key | Action |
|---|---|
| h/j/k/l | Move window left/down/up/right |
| y/u/i/o | Join window left/up/down/right |
| n/p | Move window to next/prev workspace |
| Space | Toggle float |
| z | Toggle fullscreen (within gaps) |
| b | Toggle layout orientation |
| s | Toggle stack layout |
| c | Create workspace |
| m | Cmd+M (minimize) |
| x | Cmd+W (close window) |

### 5. Inline Rule (in index.ts)

`escape` -> `grave_accent_and_tilde` (backtick/tilde key)

## Support Files

### polyfill.ts

```typescript
import { createRequire } from "node:module";
(globalThis as any).require = createRequire(import.meta.url);
```

Must be imported first in `index.ts` (`import "../polyfill.ts"`) before any karabiner.ts imports work.

### leader-utils.ts

Exports `exitLeader()` which returns `[toSetVar("system_leader", 0)]`. Used by cap-modifier.ts to reset the leader variable when Caps is tapped alone.

## karabiner.ts API Basics

```typescript
import { rule, map, simlayer, writeToProfile, ifVar, toSetVar, ifApp, to$ } from "karabiner.ts";

// Create a named rule with manipulators
rule("My Rule").manipulators([
  map("a").to("b"),                                    // a -> b
  map("a").to({ key_code: "b", modifiers: ["left_control"] }), // a -> Ctrl+b
]);

// Simlayer: hold trigger + press key simultaneously
simlayer("f", "my-layer").manipulators([
  map("j").to("down_arrow"),
  map("k").to("up_arrow"),
]);

// Conditional rules using variables
rule("Conditional").manipulators([{
  type: "basic",
  from: { key_code: "h" },
  to: [{ key_code: "left_arrow" }],
  conditions: [{ type: "variable_if", name: "my_var", value: 1 }],
}]);

// Variable-based layer (dual-role key)
rule("Layer Toggle").manipulators([{
  type: "basic",
  from: { key_code: "caps_lock" },
  to: [{ set_variable: { name: "my_layer", value: 1 } }],
  to_if_alone: [{ key_code: "escape" }],
  to_after_key_up: [{ set_variable: { name: "my_layer", value: 0 } }],
}]);

// Per-app conditions
rule("App-specific", ifApp("^com\\.apple\\.Terminal")).manipulators([...]);
rule("Non-terminal", ifApp("^com\\.apple\\.Terminal").unless()).manipulators([...]);

// Shell commands
rule("Shell").manipulators([{
  type: "basic",
  from: { key_code: "f" },
  to: [to$("open -a Finder")],
}]);

// Write the profile
writeToProfile({ name: "default", dryRun: false, karabinerJsonPath }, [
  ...myRules,
  ...otherRules,
]);
```

## How to Add New Rules

1. Create a new file in `src/` with kebab-case naming (e.g., `src/my-feature.ts`)
2. Import polyfill is NOT needed in individual modules (only in `index.ts`)
3. Export a rules array:
   ```typescript
   import { rule, map } from "karabiner.ts";
   export const myFeatureRules = [
     rule("My Feature").manipulators([
       map("some_key").to("other_key"),
     ]),
   ];
   ```
4. Import in `src/index.ts`:
   ```typescript
   import { myFeatureRules } from "./my-feature.ts";
   ```
5. Add to the `writeToProfile()` array (position determines priority -- earlier = higher):
   ```typescript
   writeToProfile({ name: "default", dryRun: false, karabinerJsonPath }, [
     ...capsRules,
     ...modifierSwapRules,
     ...layerRules,
     ...tabWindowManagerRules,
     ...myFeatureRules,  // <-- add here
     rule("escape -> grave_accent_and_tilde").manipulators([...]),
   ]);
   ```
6. Build and reload:
   ```bash
   deno task build && karabiner-reload.sh
   ```

## How to Add Simlayer Keys

In `layers.ts`, find the target simlayer and add a new `map()` entry:

```typescript
simlayer("a", "delimiters layer").manipulators([
  // ... existing mappings ...
  map("new_key").to("target_key"),
  // or with modifiers:
  map("new_key").to({ key_code: "target", modifiers: ["left_shift"] }),
]),
```

## Important Notes

- Output path is `mods/dotfiles/karabiner.json` -- one directory UP from `karabiner/`. Do NOT put output inside the source directory.
- Do NOT manually edit `~/.config/karabiner/karabiner.json` -- it is a symlink to the generated file.
- Always commit BOTH the TypeScript sources AND the generated `karabiner.json`.
- Run `deno task build` from the `mods/dotfiles/karabiner/` directory after any change.
- Run `karabiner-reload.sh` or restart Karabiner-Elements (`osascript -e 'quit app "Karabiner-Elements"' && sleep 1 && open -a 'Karabiner-Elements'`) to apply changes.
- The `polyfill.ts` import MUST come before any `karabiner.ts` imports in `index.ts`.
- When adding variable-based layers (like caps-modifier or window-layer), use raw manipulator objects with `set_variable`, `variable_if`, `to_if_alone`, and `to_after_key_up` for dual-role behavior.
- Simlayers (from `layers.ts`) use the higher-level `simlayer()` API which handles the variable mechanics automatically.
