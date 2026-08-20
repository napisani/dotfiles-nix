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
7. [Future improvements (consolidation and monitoring)](#future-improvements-consolidation-and-monitoring)

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
| **Root cause** | `.tmux.conf` (formerly) set `extended-keys on` / `extended-keys-format csi-u` globally, enabling Kitty-keyboard-protocol key reporting (needed for Neovim/agent CLIs to disambiguate e.g. Ctrl-I from Tab, or get Shift+Enter). tmux has a known bug — [tmux/tmux#4663](https://github.com/tmux/tmux/issues/4663) — where it also re-encodes newlines **inside a bracketed paste** as literal CSI-u escape text, even though the protocol spec says paste content should pass through untouched. Reproduced directly on tmux 3.7b (the issue's fix, if any, didn't hold for this build). |
| **Options considered and rejected** | (1) Leave `extended-keys` on always — pastes stay broken. (2) Toggle it via Neovim `FocusGained`/`FocusLost` autocmds only — misses agent CLIs (claude/codex/pi/opencode) run directly at the shell, which also need Shift+Enter. (3) Toggle via tmux hooks (`pane-focus-in`, `window-pane-changed`) keyed on `#{pane_current_command}` — tested directly against real `select-pane`/`select-window` (the same commands the `h`/`j`/`k`/`l` pane bindings use) and neither hook fired in this tmux 3.7b build, even though other hooks like `after-select-window` did. |
| **Workaround (current)** | `mods/dotfiles/.tmux.conf` defaults `extended-keys off`. `mods/dotfiles/.bashrc.d/0069_tmux_extended_keys.bashrc` defines shell wrapper functions for `nvim`, `vim`, `claude`, `codex`, `pi`, `opencode` that flip `tmux set-option -g extended-keys always` right before exec'ing the real binary and back `off` right after it exits, via a `_TMUX_EXTKEYS_DEPTH` counter so nesting one inside another (e.g. `nvim` opened from inside `claude`) doesn't turn it off early on the inner exit. |
| **`on` vs. `always`** | The wrapper's active state must be `always`, not `on`. `on` only forwards the enhanced encoding if tmux detected the outer terminal supports it, and that detection appears to happen once at client-attach time — since the session now starts at `off`, switching to `on` later left tmux still thinking the client couldn't handle it: confirmed live, Shift+Enter in an already-running Pi session silently degraded to plain Enter with `extended-keys on`, and started working immediately (no restart) the moment it was switched to `extended-keys always` instead. |
| **Known limitation** | A program invoked another way — e.g. `nvim` launched as `$EDITOR` by a non-interactive subshell that doesn't source `.bashrc.d` — skips the wrapper and runs with whatever `extended-keys` state was already set. |
| **Rollout note** | `.tmux.conf` is a live out-of-store symlink (`tmux source-file` picks up edits immediately); `.bashrc.d` is copied into the Nix store at build time (`shell.nix`: `".bashrc.d".source = ./dotfiles/.bashrc.d;`), so the wrapper file needs an actual `darwin-rebuild switch` before a new shell sees it — unlike `shell_scripts/`, which is a whole-directory live symlink. |
| **Revisit when** | tmux ships a real fix for [tmux/tmux#4663](https://github.com/tmux/tmux/issues/4663) (test by removing the wrapper and pasting multi-line text at a plain prompt), or a per-window/per-pane override for `extended-keys` becomes possible (confirmed empirically on 3.7b: even a `-w`-flagged `set-option` mutates the global value, so it's effectively server-wide only). |
| **Related upstream reports** | [tmux/tmux#4663](https://github.com/tmux/tmux/issues/4663) — this bug, closed upstream against an older tmux but still reproduces on 3.7b. Also see the related, still-open [neovim/neovim#38021](https://github.com/neovim/neovim/issues/38021) ("Bracketed paste under tmux is contaminated with extended keys") for the same root cause from Neovim's side. |

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
| *(add entries when adding/removing workarounds)* | |
