# Copilot NES Failure with Sidekick.nvim

## Summary

- **Observed Behavior:** Triggering Next Edit Suggestions (NES) through Sidekick.nvim returns no edits. `require("sidekick.nes").have()` stays `false` even after manual `nes.update()` calls.
- **Expected Behavior:** Copilot LSP should respond to `textDocument/copilotInlineEdit` requests with edit suggestions for Sidekick to display.
- **Impact:** NES functionality is unusable. Inline completions still work, but Sidekick cannot surface diff-style edits.

## Environment

- **OS:** macOS (managed via Nix Home-Manager; repo contains `systems/profiles/darwin-work.nix`)
- **Neovim:** 0.11.5 (from `NVIM_APPNAME=nvim` setup)
- **Sidekick.nvim:** latest `main` (pulled via `lazy.nvim`)
- **GitHub Copilot Plugins:**
  - `github/copilot.vim@release` (managed via `lazy.nvim`)
  - `@github/copilot-language-server@1.420.0` installed through Mason (`:MasonInstall copilot-language-server`)
- **Sidekick Configuration:**
  - NES manually disabled for now: `nes = { enabled = false, debug = true }`
  - CLI mux disabled (`mux.enabled = false`)
  - Keymaps bound under `<leader>A` for Opencode-first workflow
- **Copilot LSP enablement:** `vim.lsp.enable("copilot")` inside `mods/dotfiles/nvim/lua/user/lsp/init.lua`

## Reproduction Steps

1. Install dependencies via `lazy.nvim` / Mason (Copilot plugin + language server).
2. Authenticate Copilot LSP (`:LspCopilotSignIn` succeeded; `:LspInfo` shows Copilot attached).
3. Open any buffer with Copilot enabled (e.g., `mods/dotfiles/nvim/lua/user/plugins/ai/sidekick.lua`).
4. Trigger Sidekick NES manually: `<leader>AN` (mapped to `require("sidekick.nes").update()`).
5. Observe that no inline diff appears. `:lua print(require("sidekick.nes").have())` returns `false`.
6. Repeat in a simple scratch buffer with minimal code; behavior persists.

## Observed Logs

- `~/.local/state/nvim/lsp.log` shows repeated Copilot server errors when NES is triggered:

```
BugIndicatingError: Assertion Failed: unexpected state
  at assert (.../nextEditSuggestions/.../assert.ts:36:15)
  at new Edit (.../nextEditSuggestions/.../edit.ts:89:9)
  at Function.create (.../nextEditSuggestions/.../edit.ts:32:16)
  at joinEdits (.../nextEditSuggestions/.../edit.ts:405:17)
  at t.compose (.../nextEditSuggestions/.../edit.ts:97:16)
  ...
```

- Copilot server also emits `AbortError: The operation was aborted.` for the same requests.
- Sidekick debug output confirms `nes` requests are sent but never populate `_requests`.

## Diagnostics Performed

- Confirmed Copilot LSP attaches headlessly: `nvim --headless -c "lua ... vim.lsp.get_clients({name='copilot'}) ..."`.
- Verified Mason manages `copilot-language-server` (see `mods/dotfiles/nvim/lua/user/lsp/mason.lua`).
- Disabled tmux mux backend to rule out terminal side-effects.
- Enabled Sidekick debug logging (`debug = true`) to trace NES lifecycle.
- Ran manual NES probe in scratch buffer; still no edits, same log errors.
- Checked for `vim.lsp.inline_completion` availability; guarded enablement to avoid older Neovim crashes.

## Suspected Root Cause

The Copilot language server fails while composing NES edits (`BugIndicatingError: unexpected state`). This looks like an upstream bug in `@github/copilot-language-server` (inline edit pipeline). Sidekick never receives valid edits because the server aborts the request.

## Workaround

- NES temporarily disabled: `nes = { enabled = false, debug = true }` in `mods/dotfiles/nvim/lua/user/plugins/ai/sidekick.lua`.
- Continue using inline completions and CLI workflows until Copilot resolves the NES edit bug.

## Suggested Next Steps

1. Report to GitHub Copilot support or `copilot-language-server` maintainers with the stack trace above.
2. Re-enable NES once upstream releases a fix. Remove the temporary guard in `sidekick.lua`.
3. Optionally, keep Sidekick debug logging to capture future regressions.
