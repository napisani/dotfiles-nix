# Workarounds and upstream tracking

This document lists **temporary fixes** applied in this flake (Neovim config, Nix overlays, and related hacks), **why** they exist, and **what to revisit** when upstream fixes land. Goal: eventually drop workarounds and use stock behavior.

---

## Table of contents

1. [Neovim / Lua](#neovim--lua)
2. [nvim-treesitter configuration](#nvim-treesitter-configuration)
3. [Nix / Home Manager config notes](#nix--home-manager-config-notes)
4. [tmux `extended-keys` vs. multi-line paste](#tmux-extended-keys-vs-multi-line-paste)
5. [Neovim 0.12 `:checkhealth` remediation plan](#neovim-012-checkhealth-remediation-plan)
6. [fff.nvim binary (lazy.nvim build hook)](#fffnvim-binary-lazyvim-build-hook)
7. [Pi extensions: `claude-agent-sdk-pi` peer-dep conflict](#pi-extensions-claude-agent-sdk-pi-peer-dep-conflict)
8. [Pi `claude-bridge` CLI model resolution](#pi-claude-bridge-cli-model-resolution)
9. [`npm config set prefix` vs. immutable `~/.npmrc`](#npm-config-set-prefix-vs-immutable-npmrc)
10. [OmniWM focused-border rendering](#omniwm-focused-border-rendering)
11. [Future improvements (consolidation and monitoring)](#future-improvements-consolidation-and-monitoring)

---

## Neovim / Lua

### `vim.tbl_flatten` deprecation (Neovim 0.11+)

| Item | Detail |
|------|--------|
| **Location** | `mods/dotfiles/nvim/lua/user/compat.lua` |
| **What** | Shadow `vim.tbl_flatten` with a `vim.iter`-based implementation before lazy.nvim loads. |
| **Why** | Some plugins still call deprecated `vim.tbl_flatten`; Neovim emits `vim.deprecated` noise. |
| **Remove when** | Plugins you rely on no longer use `vim.tbl_flatten`, or Neovim removes the deprecation path you care about. |
| **How to verify** | Open Neovim with `:messages` clean after normal use; grep plugin updates / changelogs for `tbl_flatten`. |

### `vim.validate{ <table> }` deprecation (Neovim 0.12+, removed in Nvim 1.0)

| Item | Detail |
|------|--------|
| **Location** | `mods/dotfiles/nvim/lua/user/compat.lua` |
| **What** | Replace `vim.validate` with a wrapper: if the first argument is a table (deprecated spec form), expand each field to positional `vim.validate(name, value, validator, …)` on the **original** function. Short type aliases (`n`, `s`, `t`, …) are mapped to full Lua type names because the positional API does not accept aliases. |
| **Why** | Several plugins still use the table form; Neovim logs `vim.deprecate` and `:checkhealth vim.deprecated` reports it. |
| **Remove when** | Upstream plugins use only the positional form; `:checkhealth vim.deprecated` stays clean **without** this wrapper. |
| **How to verify** | `nvim --headless -u init.vim -c "checkhealth vim.deprecated" -c "qa"` from `mods/dotfiles/nvim` (or interactive `:checkhealth vim.deprecated`). |

### Experimental `ui2` (Neovim 0.12+)

| Item | Detail |
|------|--------|
| **Location** | `mods/dotfiles/nvim/lua/user/options.lua` (after `vim.opt` setup); opt-out in `mods/dotfiles/nvim/init.vim` (commented `vim.g.user_ui2 = false` before `require("user.init")`). |
| **What** | `pcall(function() require("vim._core.ui2").enable({}) end)` when `g:user_ui2` is not `false`. |
| **Why** | Reduces legacy “Press ENTER” style interruptions and refreshes cmdline UX; aligns with the 0.12 refresh plan. Wrapped in `pcall` so missing/private API on some builds fails silently. |
| **Remove / revisit** | If ui2 becomes default upstream or you drop the experiment, delete the block and the init.vim comment. If statusline/plugins misbehave, set `vim.g.user_ui2 = false`. |

### Markdown Treesitter highlighter crashes (Neovim 0.12+)

| Item | Detail |
|------|--------|
| **Symptom** | `Decoration provider "start" (ns=nvim.treesitter.highlighter)` → `attempt to call method 'range' (a nil value)` in `vim/treesitter.lua` / `languagetree.lua` during parse. |
| **Upstream** | Known fragile area: markdown + `markdown_inline` + injections (e.g. fenced code); see [nvim-treesitter#8618](https://github.com/nvim-treesitter/nvim-treesitter/issues/8618) and related Neovim TS issues. Often worsened by **parser ABI / query mismatch** vs the editor build — run `:TSUpdate` after upgrading Neovim. |
| **Primary mitigation** | `mods/dotfiles/nvim/lua/user/plugins/code/treesitter.lua` skips `vim.treesitter.start()` for `markdown` / `markdown_inline` / `css` in a `FileType` autocommand (nvim-treesitter **main** has no `configs` highlight module). |
| **Secondary (plugins)** | Plugins that call `vim.treesitter.start(buf, "markdown")` on **nofile** buffers bypass module `disable`. `mods/dotfiles/nvim/lua/user/compat.lua` wraps `vim.treesitter.start` for those calls. |
| **Escape hatch** | Set `vim.g.user_ts_markdown_treesitter = true` **before** `require("user.compat")` to allow TS markdown again. |
| **Remove when** | Confirmed stable on your Neovim version with real markdown / Agentic / Snacks buffers; then drop `markdown` from highlight `disable` and remove or narrow the compat shim. |

---

## nvim-treesitter configuration

| Item | Detail |
|------|--------|
| **Location** | `mods/dotfiles/nvim/lua/user/plugins/code/treesitter.lua` |
| **Tree-sitter CLI** | Install **`tree-sitter`** from Nix (same role as Homebrew’s `tree-sitter-cli`), e.g. `mods/base-packages.nix` → `home.packages` via `pkgs-unstable.tree-sitter`. Ensures `tree-sitter` is on `PATH` in shells where you run Neovim so `:TSInstall` / parser compilation can use it. |
| **Lazy pin** | `nvim-treesitter/nvim-treesitter` uses **`branch = "main"`** in `lua/user/lazy.lua` (`master` lags). |
| **API (`main` branch)** | **Incompatible** with legacy `master`: there is **no** `nvim-treesitter.configs`. Use `require("nvim-treesitter").setup { install_dir = … }`, `FileType` → `vim.treesitter.start()` for highlight, and `indentexpr` → `v:lua.require'nvim-treesitter'.indentexpr()` per [upstream README](https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md). `mods/dotfiles/nvim/lua/user/plugins/code/treesitter.lua` implements this. |
| **`install_dir`** | Passed to `setup()` (same idea as old `parser_install_dir` on `configs`): `stdpath("data")/site` so parsers are writable; use `:TSUpdate` after Neovim/plugin bumps. |
| **Highlight / indent** | **Per-buffer** via one `FileType` autocommand: skip TS highlight/indent for the same languages as before (`markdown` / `markdown_inline`, `css`, plus python/css/markdown for indent only). Other filetypes: `pcall(vim.treesitter.start, 0)` and treesitter `indentexpr`. |
| **Auto-install loop** | Compare `config.get_installed("parsers")` to `vim.tbl_keys(require("nvim-treesitter.parsers"))`, then `require("nvim-treesitter").install(missing)` **without** `:wait()` so startup is not blocked (same ignore list as before: `phpdoc`, etc.). Use `:wait()` only in a deliberate bootstrap script if needed. |
| **Remove / tighten when** | Replace the “install all missing” loop with an explicit allowlist (install only langs you use) if downloads or disk use become a problem. |

---

## Nix / Home Manager config notes

| Item | Detail |
|------|--------|
| **`allowUnfreePredicate = (_: true)`** | Documented in `homes/home-supermicro.nix` as a workaround for [home-manager#2942](https://github.com/nix-community/home-manager/issues/2942)-style unfree evaluation. Revisit if HM/nixpkgs simplify unfree handling. |

---

## tmux `extended-keys` vs. multi-line paste

| Item | Detail |
|------|--------|
| **Symptom** | Pasting multi-line text (e.g. a shell command with `\` line continuations) at a plain shell prompt inside tmux inserts literal garbage like `^[[106;5u` instead of the real newlines, corrupting the paste. |
| **Root cause** | `.tmux.conf` (formerly) set `extended-keys on` / `extended-keys-format csi-u` globally, enabling Kitty-keyboard-protocol key reporting (needed for Neovim/agent CLIs to disambiguate modified keys such as Shift+Enter). tmux has a known bug — [tmux/tmux#4663](https://github.com/tmux/tmux/issues/4663) — where it also re-encodes newlines **inside a bracketed paste** as literal CSI-u escape text, even though the protocol spec says paste content should pass through untouched. Reproduced directly on tmux 3.7c; neither the 3.8-rc notes nor current master identify a confirmed fix. |
| **Options considered and rejected** | (1) Leave `extended-keys` on/always — pastes stay broken. (2) Toggle it around agent CLIs — the setting is server-wide, so an open Pi/Claude/Neovim pane still corrupts pastes in every other pane or attached client. (3) Toggle it from focus hooks — this remains server-wide and is ambiguous when multiple tmux clients are attached. |
| **Workaround (current)** | Keep `extended-keys off` permanently. Alacritty explicitly emits CSI-u for the specialty chords used by Neovim and agent CLIs; matching root-table bindings in `mods/dotfiles/.tmux.conf` forward those exact bytes with `send-keys -H`. This preserves Shift/Ctrl/Alt+Enter and the other configured chords without turning on tmux's buggy blanket re-encoding. |
| **Why explicit forwarding works** | With `extended-keys off`, tmux still recognizes an incoming CSI-u key but normally degrades it to the legacy unmodified byte (for example, Shift+Enter becomes carriage return). A root binding matches tmux's decoded key and emits the original CSI-u bytes directly to the pane. |
| **Known limitation** | Only chords explicitly listed in both `alacritty.toml` and `.tmux.conf` remain distinguishable. Keep the two lists synchronized when adding a specialty key. |
| **Rollout note** | Both files are live out-of-store symlinks. Reload tmux with `tmux source-file ~/.tmux.conf`; Alacritty key-binding changes require a config reload/new window. The removed shell wrapper no longer requires a Home Manager rebuild. |
| **Revisit when** | tmux ships a confirmed fix for [tmux/tmux#4663](https://github.com/tmux/tmux/issues/4663) (test by temporarily removing the explicit forwarding bindings, enabling `extended-keys`, and pasting multi-line text at both a plain prompt and inside Neovim), or a per-window/per-pane override for `extended-keys` becomes possible (confirmed empirically on 3.7c: even a `-w`-flagged `set-option` mutates the server value). |
| **Related upstream reports** | [tmux/tmux#4663](https://github.com/tmux/tmux/issues/4663) is closed without a linked fixing commit or release. [neovim/neovim#38021](https://github.com/neovim/neovim/issues/38021) documents the same contamination and is closed as blocked on an external fix. |

---

## Neovim 0.12 `:checkhealth` remediation plan

Captured with NVIM v0.12.0 using `mods/dotfiles/nvim` (`init.vim` → `user/init.lua`). Full report can be saved interactively with:

```vim
:checkhealth
:w ~/checkhealth.txt
```

Or from a **real terminal** (recommended; see below):

```bash
cd "$DOTFILES_HOME_MANAGER_DIR/mods/dotfiles/nvim" && nvim -u init.vim "+checkhealth" "+write! /tmp/nvim-checkhealth.txt" "+qa"
```

### Headless vs interactive (important)

| Observation | Explanation |
|-------------|-------------|
| `$TERM: dumb` in `vim.health` | Normal for `nvim --headless`; triggers **tmux `$TERM` mismatch** warning vs `default-terminal` — not representative of daily use. |
| Snacks `vim.ui.input` / `vim.ui.select` “not set to Snacks” | Snacks hooks `vim.ui` when the plugin loads; headless/early health may run before hooks apply. **Re-run `:checkhealth` inside tmux/kitty with normal `$TERM`.** |

**Workaround (documented):** Treat **headless** health as CI-only; use **interactive** `:checkhealth` for Snacks, terminal, and UI truth.

---

### Priority matrix (from latest run)

| Priority | Area | What checkhealth showed | Action |
|----------|------|-------------------------|--------|
| **P0** | `vim.deprecated` | `vim.validate{ <table> }` deprecated (Nvim 1.0 removal planned). Stack traces pointed at **codecompanion.nvim** (`utils/log.lua`) and **dadbod-grip.nvim** (`init.lua`). | **In-repo:** `mods/dotfiles/nvim/lua/user/compat.lua` wraps `vim.validate`, expands the deprecated table form to the positional API (and expands short type aliases `n`/`s`/…). Revisit when those plugins ship the new callsite style; then the shim can be dropped. |
| **P1** | Snacks (interactive) | If still ERROR after interactive run: `vim.ui.input` / `vim.ui.select` not Snacks; missing image/LaTeX/Mermaid tools; `lazygit`; kitty graphics. | Align with [snacks.nvim](https://github.com/folke/snacks.nvim) docs: ensure `require("snacks").setup` runs early (`lazy = false` already); optionally install optional tools or **accept** warnings for unused features. |
| **P2** | Lazy / luarocks | Wants Lua 5.1 for luarocks; Neovim uses **LuaJIT**. | **Ignore** unless a plugin requires luarocks build; lazy’s own health says no plugins need luarocks. |
| **P2** | ~~LuaSnip~~ | *(removed)* LuaSnip / friendly-snippets dropped; blink uses `lsp` + `path` + `buffer` only. |
| **P2** | Mason | Optional language runtimes (cargo, composer, php, javac, julia, pip, …) not on PATH. | Install only what you need via Nix or Mason; warnings are **informational**. |
| **P3** | `vim.lsp` | “Unknown filetype” for composite fts (`eelixir`, `surface`, `gowork`, `yaml.*`, …). | Cosmetic: add `vim.filetype.add` aliases if those projects matter, or ignore. |
| **P3** | Agentic | Optional ACP backends not installed. | Expected unless you use those providers. |
| **P3** | blink.cmp | “Some providers disabled dynamically”. | Informational. |

---

### Workarounds to track in this file (checkhealth-related)

| Issue | Workaround / note | Remove when |
|-------|-------------------|-------------|
| **`vim.validate` table API** | `compat.lua` intercepts `vim.validate(spec)` and forwards to `vim.validate(name, val, …)` so `vim.deprecate` is not triggered. | **codecompanion** / **dadbod-grip** (and any other plugin) switch to positional `vim.validate`; grep `vim.validate` in lazy plugins / run `:checkhealth vim.deprecated`. |
| **Headless health noise** | Use interactive `:checkhealth` for UI/terminal/Snacks. | If you add a scripted check, set `TERM=xterm-256color` and account for lazy load. |
| **Tmux `$TERM` vs `default-terminal`** | In real tmux sessions, set `default-terminal` and shell `TERM` consistently (e.g. both `tmux-256color` or both `xterm-256color` per your stack). | N/A (environment contract). |

---

## fff.nvim binary (lazy.nvim build hook)

| Item | Detail |
|------|--------|
| **Location** | `mods/dotfiles/nvim/lua/user/lazy.lua` (`dmtrKovalenko/fff.nvim` spec, `build` hook) |
| **What** | `fff.nvim` ships a Rust binary (`libfff_nvim.dylib` / `.so`). The lazy.nvim `build` hook calls `require("fff.download").download_or_build_binary()` to fetch or compile it on first install. |
| **Why** | The Nix setup uses lazy.nvim for all plugin management (no `extraPlugins`), so plugins are not provided by Nix. The binary is not available until `:Lazy sync` (or the build hook) runs on first setup. |
| **nixpkgs status** | `vimPlugins.fff-nvim` **is** packaged in nixpkgs (as of 0.5.1). The nixpkgs variant patches `download.lua` to hardcode the Nix store path, bypassing the download. |
| **Revisit when** | If lazy.nvim is replaced with Nix-managed plugins (`programs.neovim.extraPlugins`), switch to `pkgs-unstable.vimPlugins.fff-nvim` and remove the build hook. The nixpkgs package is already Nix-aware. |
| **Impact** | On a fresh install, fff.nvim will not work until `:Lazy sync` completes and the build hook runs (downloads ~4–5 MB from GitHub). Subsequent starts are fine. |

---

## Pi extensions: `claude-agent-sdk-pi` peer-dep conflict

| Item | Detail |
|------|--------|
| **Location** | `mods/agents/default.nix` (`agents.pi.packages`) |
| **Symptom** | `pi` fails to start with `Error: Failed to load extension ".../node_modules/pi-vim/index.ts": Failed to load extension: Cannot find module '@earendil-works/pi-coding-agent'`, `Require stack: - .../node_modules/pi-vim/clipboard-mirror.ts`. |
| **Root cause** | `pi install` resolves the whole `~/.pi/agent/npm` package tree (all declared extensions) together via npm. `claude-agent-sdk-pi`'s latest published version (`1.0.22`) peer-deps on `@earendil-works/pi-ai@^0.74.0`, while every other declared extension (`pi-web-access`, `pi-mcp-adapter`, `@juicesharp/rpiv-btw`) now needs `pi-ai@0.84.x`. `^0.74.0` on a `0.x` package only allows patch bumps (`>=0.74.0 <0.75.0`), so it's incompatible with `0.84.3` — a real `ERESOLVE` conflict, not a version-pinning choice on our side. That conflict makes npm silently skip auto-installing peer deps for **every** extension in the tree (not just `claude-agent-sdk-pi`'s own), which is what left `pi-vim`'s peer dep on `@earendil-works/pi-coding-agent` unmet. |
| **How it was diagnosed** | Reproduced directly: ran `pi install npm:pi-vim` (via the real binary, `/Users/nick/.local/bin/pi`, bypassing the tmux shell wrapper — see below), confirmed `npm ls @earendil-works/pi-coding-agent` showed unmet, then ran `npm install ... --no-save` in `~/.pi/agent/npm` and got an explicit `ERESOLVE` error naming `claude-agent-sdk-pi@1.0.22` as the conflicting peer. Removing it from that project's `package.json` and reinstalling resolved cleanly and installed `@earendil-works/pi-coding-agent`; the extension-load error disappeared. |
| **Workaround (current)** | Dropped `"npm:claude-agent-sdk-pi"` from `agents.pi.packages` in `mods/agents/default.nix`. The diff-and-prune mechanism in `apply-pi-packages.js` runs `pi remove npm:claude-agent-sdk-pi` on the next `home-manager switch` since it's no longer declared. That alone was **not** sufficient, though: `pi install`/`pi remove` act on one package at a time and don't reconcile the shared `~/.pi/agent/npm` tree as a whole, so removing the conflicting peer range did not retroactively install the now-satisfiable peers — `pi-vim` still failed with the same error until a plain `npm install` was run in that directory by hand. `apply-pi-packages.js` now runs that `npm install` reconcile after managed installs/removals (including repairs), retaining pending progress when finalization fails. Healthy unchanged activations skip Pi installers and npm reconciliation. Routine probes check declared artifacts and exact pins rather than the entire transitive npm tree; use `GLOBAL_TOOLS_FORCE_REPAIR=1` for dependency damage outside those bounded checks. |
| **Unrelated red herring** | A concurrent `npm error EACCES` on `~/.npmrc` (root-owned `~/.npm` cache files from a past `sudo npm install`) was also present and broke `installNpmxTools` during activation. That's a real local-machine issue worth fixing (`sudo chown -R $(id -u):$(id -g) ~/.npm ~/.npmrc`), but it was **not** the cause of the `pi-vim` extension error — the peer-dep conflict above was. |
| **Debugging gotcha** | Running `pi` directly through the Bash tool (or any non-interactive/non-`.bashrc.d`-sourcing shell) can hit `bash: command not found: _tmux_extended_keys_wrap` — the `pi()` shell function from [the tmux `extended-keys` workaround](#tmux-extended-keys-vs-multi-line-paste) gets inherited via an exported function without its helper. Use the real binary path (`/Users/nick/.local/bin/pi`) to bypass the wrapper when debugging in that kind of shell. |
| **Revisit when** | Upstream bumps `claude-agent-sdk-pi`'s peer range off of `pi-ai@^0.74.0` **and** ships a version built against the current `pi-ai` models interface. Check with `npm view claude-agent-sdk-pi version peerDependencies`; re-add `"npm:claude-agent-sdk-pi"` to `agents.pi.packages` once both hold. |
| **Recheck 2026-09-04** | Still blocked, and the blocker is now deeper than a peer range. Upstream is unchanged at `1.0.22` (published 2026-05-16, ~4 months stale) with `pi-ai@^0.74.0`. Re-adding it reproduces the same `ERESOLVE` against `pi-mcp-adapter@2.32.1`'s `peerOptional pi-ai@^0.84.1`. Forcing resolution with root overrides for `pi-ai` and `pi-coding-agent` `0.85.0` installs cleanly, but the extension then fails to load because it calls the removed `getModels("anthropic")`. Re-adding requires either an upstream release or a patched fork. Decision: stay out. |

---

## Pi `claude-bridge` CLI model resolution

| Item | Detail |
|------|--------|
| **Location** | `mods/dotfiles/agents/pi/extensions/claude-bridge-cli-model.js` and its adjacent `.test.cjs` test. |
| **Symptom** | `pi --provider claude-bridge --model claude-sonnet-5 …` and `pi --model claude-bridge/claude-sonnet-5 …` silently run the request with Pi's global default model instead (currently `openai-codex/gpt-5.6-luna`). The response's JSON `provider` and `model` fields expose the mismatch; the TUI status alone is not reliable evidence. |
| **Root cause** | `pi-claude-bridge` guards provider registration across multiple module instances. Its first instance queues registration during extension load, but a later instance can defer its registry-specific decision until `session_start`. Pi resolves built-in `--provider`/`--model` arguments before that deferred provider is visible, retains the unrelated fallback, and can restore that fallback after early startup handlers. Interactive `/model` works because registration is complete by then. |
| **Workaround (current)** | The global extension reads only explicit `claude-bridge` selections from `process.argv`. It tries `ctx.modelRegistry.find()` during `resources_discover`, then reasserts the requested model exactly once in `before_agent_start` with `pi.setModel()`. The final barrier is strict: an unavailable requested bridge model exits with status 1 instead of dispatching to another provider. Explicit `--thinking` and `:<thinking>` model suffixes are preserved. Non-bridge model selection is untouched. |
| **Why two barriers** | `resources_discover` runs after the bridge's deferred `session_start` registration and makes the model visible before normal interaction. Pi can subsequently restore the prematurely resolved fallback, so the first `before_agent_start` must reassert the requested model immediately before provider dispatch. Applying only during `session_start` was tested and failed for this reason. |
| **Known limit** | This repairs `--provider` plus `--model`, and provider-qualified `--model`. It does not rewrite `--models` scoped-model resolution because `ctx.scopedModels` is read-only after Pi has resolved it. |
| **How to verify** | Run `pi --provider claude-bridge --model claude-sonnet-5 --mode json --no-tools --no-skills --no-context-files --no-themes -p 'Reply with exactly OK.'` and inspect the assistant `message_end` event for `"provider":"claude-bridge"` and `"model":"claude-sonnet-5"`. Run `node --test mods/dotfiles/agents/pi/extensions/claude-bridge-cli-model.test.cjs` for the local parser/lifecycle regression suite. |
| **Remove when** | Remove the extension after Pi resolves explicit CLI models only once extension providers—including deferred bridge instances—are registered, or after `pi-claude-bridge` guarantees factory-time registration without overwriting parent/subagent stream state. Re-run the JSON verification command without the shim before removal. |

---

## Native installs repeatedly run stale activation code

Activation used `${homeManagerRelPath}/mods/dotfiles/agents/scripts`, so a flake
built from one worktree ran scripts from the mutable primary checkout. A
read-only replay of the real Pi inventory reproduced ten attempted installer
calls in that checkout versus no calls on the committed reconciler's second
run. New declarations alone could not fix an activation that ran old code.

`mods/internal/native-scripts.nix` now bundles installer scripts and their relative
imports in the Nix store. The `native-install-contract` flake check asserts
binding for every managed host and runs fixtures against that bundle. Claude/npm/Pi/uv
also share per-asset progress rather than a whole-batch success stamp. uv probes
canonicalize editable receipt paths, avoiding reinstalls when the receipt names
a symlink to the same source directory.

---

## `npm config set prefix` vs. immutable `~/.npmrc`

| Item | Detail |
|------|--------|
| **Location** | `mods/internal/npm.nix` — `~/.npmrc` content (`npmrcContent`) and the `npm-config` operation that writes it now both live here. Previously the file was declared in `mods/shell.nix` (`npmrc` let-binding, `home.file.".npmrc".text`). |
| **Symptom** | `home-manager switch` fails during `Activating installNpmxTools` with `npm error code EACCES … npm error path /Users/nick/.npmrc … Your cache folder contains root-owned files … sudo chown -R 501:20 "/Users/nick/.npm"` followed by `installNpmxTools: ERROR: npm config set prefix failed for: /Users/nick/.local`. `chown`-ing `~/.npm` as suggested does **not** fix it — the error recurs on the very next switch. |
| **Root cause** | `~/.npmrc` was Home Manager–managed (`mods/shell.nix`: `home.file.".npmrc".text = npmrc`, where `npmrc` already contained `prefix=$HOME/.local`). Home Manager links `home.file` entries as symlinks into the read-only `/nix/store` — confirmed via `readlink -f ~/.npmrc` → `/nix/store/…-hm_.npmrc`. `installNpmxTools` *also* ran `npm config set prefix "$NPM_CONFIG_PREFIX" --location=user`, which opens `~/.npmrc` for **writing** to persist the same value imperatively. That write always fails EACCES against the immutable Nix store target, no matter what `~/.npm`'s cache ownership is — npm's own error message just misattributes any EACCES during a config write to "root-owned cache files", which is a real and common npm failure mode in general, just not what was happening here. |
| **Why it looked like the cache** | npm's EACCES error text is generic and always suggests the `sudo chown -R … ~/.npm` fix, regardless of which file it actually failed to open. `~/.npm` (the cache dir) and `~/.npmrc` (the config file) are easy to conflate by name; only `readlink -f ~/.npmrc` / `ls -la ~/.npmrc` reveals the real target is a Nix store symlink, not a plain writable file. |
| **Workaround (current)** | Just deleting the `npm config set prefix` call (redundant with the declarative `~/.npmrc`) fixed the symptom, but left the underlying trap in place — `~/.npmrc` was still a read-only Nix store symlink, so anything that later needs to write to it (npm itself, `npm login`, `npm config set` for something else) would hit the exact same EACCES. Moved `~/.npmrc` management off `home.file` entirely: `mods/internal/npm.nix` now computes `npmrcContent` and applies it with a content-aware `globalToolOperations.npm-config` command (ordered before npm installs, shared by activation and the `global-tools` CLI). It atomically replaces a legacy symlink or changed file but leaves an unchanged plain file untouched. `~/.npmrc` is a plain, writable file again — colocated with the rest of this module's npm setup, and safe for any future imperative npm config write. `mods/shell.nix` no longer references `.npmrc` or `machineRoles` at all. |
| **Revisit when** | N/A — this was a bug, not a temporary upstream workaround. If another module ever wants to own part of `~/.npmrc`, extend `npmrcContent` in `npmx.nix` rather than reintroducing a `home.file` declaration for the same path. |

---

## OmniWM focused-border rendering

| Item | Detail |
|------|--------|
| **Location** | `mods/omniwm.nix` |
| **What** | Override the nixpkgs OmniWM package with the upstream 0.6.8 release. |
| **Why** | The nixpkgs 0.6.3 build renders the focused-border surface over the managed window; 0.6.8 renders it as an exterior surface below the focused window. |
| **Remove when** | nixpkgs ships an OmniWM version with the corrected focused-border behavior. |
| **How to verify** | Run OmniWM with a focused window and confirm the border does not cover its content; remove the override and compare after upgrading nixpkgs. |

---

## Future improvements (consolidation and monitoring)

### Neovim

- **After each Neovim upgrade:** run **`:TSUpdate`** (and ensure Nix `tree-sitter` CLI is on `PATH`) so parsers match `vim.treesitter.language_version`.
- Use **`:restart`** (0.12+) when iterating on plugins or early startup Lua without killing the terminal; pair with `:mksession` if you need buffers back.
- After a **Neovim point release**, try `let g:user_ts_markdown_treesitter = v:true` (or Lua equivalent) and remove the `vim.treesitter.start` wrapper if no crashes in daily use.
- Watch **nvim-treesitter** `main` README/changelog; the rewrite dropped `nvim-treesitter.configs` — keep `treesitter.lua` aligned with upstream.

### Neovim side configs (`NVIM_APPNAME`)

- Run an alternate config without touching the default: `NVIM_APPNAME=nvim-next nvim` (use matching dirs under `~/.config/`, `~/.local/share/`, `~/.local/state/`, `~/.cache/` as in `:h $NVIM_APPNAME`). Useful for testing plugins or a scratch `init.lua` next to this flake-managed config.
- Which-key: **`<leader>PR`** → `:restart` (Neovim 0.12+) for a full in-process restart when iterating on Lua/plugins.

---

## Changelog (manual)

| Date | Change |
|------|--------|
| 2026-04-03 | Added `vim.validate` table→positional shim in `compat.lua`; `vim.deprecated` health clean without waiting on plugin releases. |
| 2026-04-03 | Documented Neovim 0.12 `:checkhealth` remediation (vim.validate deprecations, EFM/gleam, headless vs interactive, Snacks/tmux notes). |
| 2026-04-03 | Removed Gleam: EFM mapping, commented `gleamPackages` in `languages/all.nix`, docs/skills. |
| 2026-04-07 | LuaSnip + friendly-snippets removed; blink default sources without `snippets`; nvim-treesitter lazy spec on `main`; document Nix `tree-sitter` CLI in this file and `base-packages.nix`. |
| 2026-04-07 | Migrated `treesitter.lua` for nvim-treesitter **`main`** (no `configs` module; `FileType` + `install()` API); updated nvim-treesitter table above. |
| 2026-04-07 | Opt-in-out **ui2** in `options.lua` + init.vim comment; WORKAROUNDS markdown TS row + future checklist (`:restart`, post-upgrade `:TSUpdate`). |
| 2026-04-07 | `completeopt` adds `menu` + `popup`; `<leader>PR` → `:restart`; LSP keymaps comment (`:h lsp-defaults`); WORKAROUNDS `NVIM_APPNAME` note. |
| 2026-04-28 | Documented fff.nvim binary download via lazy.nvim build hook; noted nixpkgs has `vimPlugins.fff-nvim` 0.5.1 (Nix-aware, patches download.lua). |
| 2026-05-07 | Removed the temporary `direnv` `CGO_ENABLED = 1` override and matching `mise` override after the locked stock `direnv-2.37.1` substituted from cache and passed a basic allow/export smoke test. |
| 2026-08-11 | Added `overlays/oxlint-darwin-ps-fix.nix` to fix `oxlint` build failing with `spawn EPERM` under the Darwin sandbox (`@napi-rs/cli` `/bin/ps` exec); mirrors the fix already merged in nixpkgs `master` but not yet promoted to `nixpkgs-unstable`. |
| 2026-08-13 | Removed `oxlint-darwin-ps-fix.nix` overlay; the fix is now in nixpkgs-unstable (oxlint 1.78.0), and the overlay was causing spurious substitution failures. |
| 2026-08-20 | Defaulted tmux `extended-keys` off (`.tmux.conf`) and added `.bashrc.d/0069_tmux_extended_keys.bashrc` shell wrappers (`nvim`/`vim`/`claude`/`codex`/`pi`/`opencode`) to toggle it only while one of those programs is running, working around tmux/tmux#4663 corrupting multi-line pastes at the shell prompt. |
| 2026-08-20 | Fixed the above: wrapper's active state must be `extended-keys always`, not `on` — `on`'s client-support detection doesn't re-trigger on a later switch, so Shift+Enter silently degraded to plain Enter until confirmed live and corrected to `always`. |
| 2026-08-27 | Dropped `npm:claude-agent-sdk-pi` from `agents.pi.packages`: its peer dep on `@earendil-works/pi-ai@^0.74.0` conflicts with the `0.84.x` other declared Pi extensions need, which blocked npm from auto-installing peer deps for the whole tree and broke `pi-vim` with a missing-module error. |
| 2026-08-27 | `apply-pi-packages.js` runs a full `npm install` reconcile in `~/.pi/agent/npm` when declarations change, health fails, or repair is forced; healthy unchanged activations skip installer work. |
| 2026-08-27 | Removed the redundant `npm config set prefix … --location=user` call from `installNpmxTools` (`npmx.nix`): it tried to write `~/.npmrc`, which is a Home Manager–managed read-only Nix store symlink that already declares the same `prefix` value (`shell.nix`), so it always failed EACCES — misdiagnosed by npm's own error text as a root-owned `~/.npm` cache problem, which `chown` couldn't actually fix. |
| 2026-08-27 | Moved `~/.npmrc` off `home.file` (`shell.nix`) entirely: `npmx.nix` now owns it as a writable plain file and atomically changes it only when needed. |
| 2026-09-16 | Removed the server-wide agent wrappers after they reproduced paste corruption in other panes while Pi was open. Kept `extended-keys off` permanently and mirrored Alacritty's explicit CSI-u chords as tmux root bindings that forward the original bytes. |
| 2026-09-21 | Added the `claude-bridge-cli-model` Pi extension workaround so explicit `--provider claude-bridge --model …` and provider-qualified `--model` selections are re-applied after deferred bridge registration and before the first provider request. |
| *(add entries when adding/removing workarounds)* | |
