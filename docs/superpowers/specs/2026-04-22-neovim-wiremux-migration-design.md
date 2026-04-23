# Neovim Wiremux Migration Design

## Summary

This change removes `codecompanion.nvim`, `agentic.nvim`, and the dependent `code_explain` integration from the Neovim config. It makes `wiremux.nvim` the only remaining general-purpose agent transport, moves the active agent namespace to `<leader>o`, removes `<leader>O`, and rewrites the file-context helpers so `<leader>af...` sends lightweight file references through Wiremux instead of mutating an in-editor chat buffer.

The first pass is intentionally minimal. It preserves Wiremux-native actions, keeps selected former Agentic keys as explicit stubs when there is no current Wiremux equivalent, and records those gaps for future Lua customizations rather than attempting to recreate Agentic behavior immediately.

## Goals

- Remove `codecompanion.nvim`, `agentic.nvim`, and `code_explain` from the active config.
- Make `wiremux.nvim` the only active agent backend.
- Consolidate agent keymaps onto `<leader>o`.
- Remove the `<leader>O` namespace.
- Preserve the existing file-context workflow by rewriting `lua/user/snacks/ai_context_files.lua` around Wiremux.
- Switch file-context sends from inline content attachments to lightweight references.
- Keep unsupported former Agentic actions visible as stubs so missing parity is explicit.

## Non-Goals

- Recreating Agentic session management on top of Wiremux in this pass.
- Building new custom Wiremux commands for model switching, mode switching, layout zooming, or edit/build flows in this pass.
- Preserving CodeCompanion chat state, adapters, or inline editing flows.
- Keeping backward-compatible `<leader>O` aliases after the migration.

## Current State

The current Neovim config has three overlapping AI surfaces:

- `agentic.nvim` owns `<leader>o` for an inline sidebar workflow.
- `wiremux.nvim` owns `<leader>O` for an external tmux-pane workflow.
- `codecompanion.nvim` owns much of the broader `<leader>a` helper surface and remains the fallback backend for some shared helper modules.

`BEHAVIOR.md` explicitly distinguishes `<leader>o` as Agentic and `<leader>O` as Wiremux. `lua/user/snacks/ai_context_files.lua` branches across Agentic, Wiremux, and CodeCompanion, and still contains CodeCompanion-specific logic for embedding file contents and mutating chat state.

## Proposed Approach

Adopt a minimal Wiremux-first migration:

1. Remove Agentic, CodeCompanion, and CodeCompanion-dependent integrations.
2. Keep `wiremux.nvim` as the only active general-purpose agent transport.
3. Move surviving Wiremux actions from `<leader>O` onto `<leader>o`.
4. Keep selected former Agentic keys as explicit stubs that notify the user when no Wiremux equivalent exists yet.
5. Rewrite `lua/user/snacks/ai_context_files.lua` so file-context flows use Wiremux-only lightweight reference payloads.

This approach is preferred because it is the smallest coherent migration that preserves the core external-agent workflow, makes unsupported behaviors explicit, and avoids inventing abstractions before real parity gaps have been observed in use.

## Plugin And Module Changes

### Remove plugin specs and registry entries

Remove these active plugin/module paths:

- `olimorris/codecompanion.nvim`
- `carlos-algms/agentic.nvim`
- `lua/user/plugins/ai/codecompanion.lua`
- `lua/user/plugins/ai/agentic.lua`
- `lua/user/plugins/ai/code_explain.lua`

Also remove their entries from `lua/user/plugin_registry.lua` so they are no longer set up and no longer contribute keymaps.

### Remove dependent helper code

Cull or rewrite helper modules that currently depend on CodeCompanion or Agentic internals, especially:

- `lua/user/snacks/ai_actions/codecompanion.lua`
- any dispatcher that defaults to CodeCompanion or Agentic as a fallback backend
- command-launcher entries that invoke CodeCompanion commands
- comments and health/setup notes that describe Agentic or CodeCompanion as active backends

Where a helper only exists for removed backends, delete it. Where a helper still supports a desired workflow, redirect it to Wiremux.

## Keymap Design

### Primary namespace

`<leader>o` becomes the only agent namespace.

`<leader>O` is removed entirely. There is no deprecation period and no hidden compatibility alias.

### Real Wiremux-backed mappings

These surviving Wiremux actions move to lowercase `<leader>o`:

- `<leader>oo` -> toggle current Wiremux target
- `<leader>o?` -> prompt for free-text input and send to the current route
- `<leader>op` -> open the prompt library picker and send the chosen prompt
- `<leader>os` -> select the active Wiremux route
- `<leader>ox` -> close the current route target
- `<leader>oq` -> close the current route target as a muscle-memory-friendly alias
- `<leader>oa` -> visual-mode send of the current selection reference or payload as supported by the rewritten Wiremux helpers

### Stubbed mappings for missing parity

These former Agentic behaviors remain visible as explicit stubs in the first pass:

- `<leader>on` -> notify that no Wiremux new-session equivalent exists yet
- `<leader>ow` -> notify that no model-switch mapping exists yet
- `<leader>om` -> notify that no mode-switch mapping exists yet
- `<leader>oz` -> notify that no zoom/layout equivalent exists yet
- `<leader>oe` -> notify that no edit/build shortcut exists yet

`<leader>oW` is removed with the uppercase namespace rather than preserved as a stub.

## File Context Workflow

### Scope

The file-context workflow behind `<leader>af...` should continue to exist after the plugin cull. The implementation changes, but the user-facing goal remains the same: quickly send file context from pickers or the current buffer into the active agent workflow.

### Backend contract

`lua/user/snacks/ai_context_files.lua` becomes Wiremux-only.

The rewrite keeps the picker-facing behavior:

- selection normalization across Snacks picker item shapes
- multi-select confirmation
- current-buffer path extraction
- shared handling of picker and direct-buffer sends

The rewrite removes backend branching:

- no Agentic path
- no CodeCompanion fallback
- no chat-buffer mutation
- no file-content attachment generation

### Payload contract

The new default payloads are lightweight references.

For full-file sends:

- include the filename or path
- do not inline file contents by default

For visual-selection sends:

- include the filename or path
- include line-number ranges
- do not inline selected text by default

For batch sends:

- send a compact list of file or selection references
- avoid one send per file when a single compact reference payload is clearer

An example payload shape is:

```text
Context references:
- file: lua/user/plugins/ai/wiremux.lua
- file: lua/user/snacks/ai_context_files.lua
- selection: lua/user/plugins/ai/wiremux.lua:42-67
```

This keeps prompts lower-noise and lower-cost, and provides a stable base for future custom commands that may expand or transform references later.

## Supporting Module Direction

After the cull, `lua/user/plugins/ai/wiremux.lua` should be the single active general-purpose AI plugin module.

Any surviving shared AI helper entry points should either:

- route directly to Wiremux, or
- be removed if they only existed to support CodeCompanion or Agentic internals

The design does not require a broad redesign of every `<leader>a` mapping in the same pass, but it does require rewriting the pieces that are necessary to keep the file-context workflows functioning on top of Wiremux.

## Behavior Documentation Updates

Update `BEHAVIOR.md` to reflect the new contract:

- `<leader>o` is the only agent namespace
- `<leader>O` no longer exists
- `<leader>o` describes an external Wiremux-based workflow rather than an inline Agentic sidebar
- `<leader>af...` documents lightweight Wiremux reference sends rather than chat attachments
- visual-selection reference sends are documented as filename plus line ranges, not inline selection contents

Remove stale notes that describe Agentic and CodeCompanion as active behavior owners.

## Error Handling

The migration should prefer explicit, local failures over silent fallback behavior.

- If Wiremux is unavailable, helper functions should notify clearly instead of silently attempting CodeCompanion or Agentic.
- Stubbed keys should notify that the behavior is intentionally not implemented yet.
- Invalid picker selections should continue to surface useful errors when no path can be derived.

This keeps the post-migration system honest: one backend, one behavior contract, and visible gaps.

## Verification Plan

Run the standard Neovim validation commands after the change:

- `nvim --headless -c "lua require('user.plugins.ai.wiremux')" -c "qa"`
- `nvim --headless -c "lua local p = require('user.whichkey.plugins'); print(vim.inspect(p.get_all_plugin_keymaps()))" -c "qa"`
- `nvim --headless -c "checkhealth" -c "qa"`

Also manually inspect the resulting keymap surface and behavior docs to confirm:

- `<leader>o` is populated by Wiremux-backed mappings and stubs only
- `<leader>O` is absent
- removed plugins no longer contribute commands or setup noise
- `<leader>af...` sends lightweight references through Wiremux

## Missing Parity List

The first pass intentionally leaves these capabilities unimplemented:

- new session creation
- model switching
- mode switching
- zoom/layout controls
- edit/build shortcut behavior
- richer file-context serialization beyond lightweight file and line-range references

These should be treated as the backlog for future Wiremux-specific Lua customizations, not as reasons to retain Agentic or CodeCompanion now.

## Rollout Outcome

After this migration, the Neovim config should present one coherent mental model:

- external agent workflow only
- one namespace for agent actions: `<leader>o`
- one active backend: Wiremux
- lightweight reference-based file context flows for `<leader>af...`

This reduces overlap, removes backend ambiguity, and creates a cleaner foundation for future workflow-specific Wiremux extensions.
