# IRIS / Atuin Ctrl-R conflict: full debug write-up

**Status:** investigation shelved — IRIS removed from the flake pending an upstream fix.
**Date:** 2026-08-15
**Upstream:** [versenilvis/iris#138](https://github.com/versenilvis/iris/issues/138)

---

## TL;DR

IRIS (a shell autocomplete/ghost-text wrapper) was integrated with `toggle-mode = "ctrl+g"` so that
Ctrl-R stays free for Atuin's history search. Two independent bugs surfaced:

1. **Config-loading bug (fixed):** the `mods/iris.nix` symlink pointed at the old
   `.config/home-manager` path, so IRIS silently fell back to its built-in `toggle-mode = "ctrl+r"`
   and hijacked Ctrl-R. Fixed by using the `homeManagerRelPath` special arg like every other module.

2. **Overlay-suppression bug (unfixed):** even with Ctrl-R correctly passed through and Atuin
   opening, IRIS kept rendering its suggestion overlay **inside Atuin's fullscreen TUI** and
   **intercepted up/down arrows** inside Atuin's filter. Root cause is in upstream IRIS's
   alt-screen detection, which is fundamentally incompatible with TUIs launched from bash
   readline bindings (which is exactly how Atuin is launched).

Because bug 2 requires patching upstream IRIS source (a `buildGoModule` flake input) and the
behavior is environment-sensitive (tmux, vi-mode readline, atuin invoked via `bind`), IRIS was
**temporarily removed** from the flake. Atuin remains on its default Ctrl-R binding.

---

## Goal (the design)

The [design spec](../superpowers/specs/2026-08-11-iris-design.md) wanted:

- **IRIS** → inline completion/ghost text, mode toggle on **Ctrl+G** (`toggle-mode = "ctrl+g"`),
  `atuin-history = 0` (IRIS never reads Atuin's history DB).
- **Atuin** → sole history-search UI on **Ctrl-R** (default binding).
- The two must not interfere.

Bash only, on all Home Manager hosts. The IRIS shell hook lives in
`mods/dotfiles/.bashrc.d/0001_iris.bashrc` and `eval "$(iris init bash)"` re-execs the interactive
shell under the IRIS wrapper.

---

## Architecture background (how IRIS wraps the shell)

`iris` replaces the interactive shell and runs `runWrapper()` (`root/wrapper.go`):

- Puts the **real terminal** in raw mode and reads keystrokes from it (the *stdin loop*).
- Launches the real shell (bash) inside a **pty**; forwards keystrokes to the pty master.
- A separate goroutine (the *output bridge*) reads the pty master and writes everything to the
  real terminal, watching for escape sequences along the way.
- Renders its suggestion overlay (ghost text + menu) by writing to the real terminal itself.

Key state: `isAltScreenActive atomic.Bool`, set by the output bridge when it sees an alternate
screen entry sequence (smcup: `\x1b[?1049h` / `\x1b[?1047h` / `\x1b[?47h`), cleared on exit
(rmcup: `...l`).

The stdin loop checks `isExecuting()` at the top of every read:

```go
if isExecuting() {
    _, _ = ptmx.Write(inputSlice[:n]) // forward everything, process nothing
    continue
}
```

`isExecuting()` returns `true` when the alt-screen is active (or a command is running), which is
what should suppress IRIS's own keystroke processing and overlay rendering while a fullscreen TUI
like Atuin is up.

---

## The symptom (as reported)

With the config correctly loaded (`toggle-mode = "ctrl+g"`, verified via `iris config show`):

1. `Ctrl-R` correctly opens Atuin's search TUI (IRIS no longer hijacks the key).
2. But while typing a filter query in Atuin, IRIS renders its own suggestions/ghost text **on top
   of the Atuin filter line**.
3. `Up`/`Down` arrows inside Atuin are intercepted by IRIS (they're IRIS's `navigate-up` /
   `navigate-down` bindings), so the user can't move the selection in Atuin's result list.

Symptoms 2+3 are exactly what you'd see if `isAltScreenActive` never got set — the stdin loop
keeps processing keystrokes (including arrows) and the render path keeps drawing the overlay.

---

## Root cause analysis

### The `isExecuting` pgrp heuristic (upstream v0.6.2, fix for #141)

At the pinned version (v0.6.3), `isExecuting()` contains:

```go
isExecuting := func() bool {
    if isAltScreenActive.Load() {
        pgrp, pgrpErr := unix.IoctlGetInt(int(ptmx.Fd()), unix.TIOCGPGRP)
        if pgrpErr == nil && pgrp == shellPGID {
            isAltScreenActive.Store(false) // ← treats it as a "probe"
        } else {
            return true
        }
    }
    ...
}
```

This check was added in [9c00f6e (fix #141)](https://github.com/versenilvis/iris/commit/9c00f6e)
to fix fish: fish's startup terminal probe emits smcup and, because the naive
`if smcup {...} else if rmcup {...}` in the output bridge sees both sequences in one read chunk,
the `rmcup` branch never runs and `isAltScreenActive` gets stuck `true` (overlay permanently
hidden). The pgrp check papers over it: if the foreground pgrp is the shell itself, assume the
smcup was a probe and reset the flag.

### Why that breaks Atuin

**Atuin's bash integration runs `atuin search -i` from a readline key binding.** In `atuin.bash`:

```bash
atuin-bind -m vi-insert '\C-r' atuin-search-viins   # → __atuin_history
__atuin_search_cmd() { ... atuin search "${search_args[@]}" -i 3>&1 1>&2 2>&3 3>&-; }
```

Commands executed from a readline `bind -x` binding run **in the shell's own process group** (they
are not dispatched as job-control jobs). So when Atuin enters the alternate screen, the pty's
`TIOCGPGRP` still reports the **shell's** PGID — the pgrp heuristic concludes "probe", resets
`isAltScreenActive` to `false`, and IRIS resumes rendering suggestions and intercepting arrows on
top of Atuin's TUI.

Verified empirically:

- `atuin search -i` definitely emits `\x1b[?1049h` (captured from a pty).
- The patched binary was confirmed installed and running (`lastAltScreenSeq` symbol present;
  running process resolved to the patched store path).
- `iris config show` confirmed `toggle-mode = "ctrl+g"` and the config symlink resolving to the
  repo file.
- Yet the debug log showed the output bridge still running its `SetPromptLen` path *after*
  Ctrl-R (that branch only runs when `isExecuting()` is `false`), i.e. `isAltScreenActive` was
  not staying set during Atuin.

### The attempted fix (removed with the rest of the work)

A local patch (`mods/iris-alt-screen-fix.patch`, applied via
`overrideAttrs { patches = ... }` in `mods/iris.nix`) did two things:

1. **Removed the `TIOCGPGRP` check** in `isExecuting()` — restore
   `if isAltScreenActive.Load() { return true }`, i.e. trust the alt-screen flag unconditionally
   while it is set.
2. **Replaced the naive `if smcup / else if rmcup` with `lastAltScreenSeq()`** — a helper that
   finds the *last* enter/exit sequence in each read chunk, so a chunk carrying both smcup and
   rmcup (fish probe) resolves to the exit state instead of getting stuck.

Rationale: fix the fish case (bug 2's root) properly at the detection layer instead of with a pgrp
heuristic that misclassifies real TUIs. The build succeeded and the binary ran, but the in-session
diagnosis (debug logging) showed the suppression still wasn't kicking in reliably, and the test
environment itself was noisy (shell-init errors in a programmatically-driven tmux pane). Combined
with the fact that this is a **source patch to a pinned flake input** that would need to be
re-verified on every IRIS update, the decision was to shelve the integration rather than carry the
patch.

### Known remaining gap

Even with the pgrp check removed, suppression relies entirely on the output bridge detecting
Atuin's smcup. The bridge's naive byte-`Contains`/`LastIndex` scanning can miss a sequence split
across two `ptmx.Read` chunks (a partial-sequence bug that also exists upstream). A robust fix
would need a small partial-tail buffer across reads. This was not pursued.

---

## Chronology of what was tried

| # | Change | Result |
|---|--------|--------|
| 1 | Reapplied the reverted IRIS commit (flake input, `mods/iris.nix`, dotfiles, bashrc hook), pinned to v0.6.3 | IRIS installed, but Ctrl-R still toggled IRIS (config not loading) |
| 2 | Applied the author's Ctrl-R→Ctrl-E workaround from issue #138 (Atuin `--disable-ctrl-r` + `atuin-bind '\C-e'`), per the original request | Reverted — user wants Ctrl-R for Atuin, and the remap doesn't fix the underlying suppression bug |
| 3 | Fixed the config symlink: `mods/iris.nix` now uses `homeManagerRelPath` (`~/code/monorepo/pub/dotfiles-nix/mods/dotfiles/…`) instead of the hardcoded `.config/home-manager` | ✅ Config loads; `toggle-mode = "ctrl+g"` honored; Ctrl-R passes through to Atuin |
| 4 | Patched `root/wrapper.go` (remove pgrp check + `lastAltScreenSeq`) via `overrideAttrs` | Built OK, binary confirmed patched, but overlay suppression still not reliable in-session |
| 5 | **Decision:** remove IRIS from the flake; Atuin keeps default Ctrl-R | This document |

Note on #2: the issue author's suggestion was to remap Atuin to Ctrl-E because even standalone
they couldn't get Ctrl-R to work with Atuin. In this setup, Ctrl-R *does* reach Atuin — the
problem is IRIS's overlay/arrow interception on top of it, which the remap does not address.

---

## Current state

- `flake.nix`: `iris` input removed.
- `homes/profiles/common.nix`: `../../mods/iris.nix` import removed.
- `mods/iris.nix`, `mods/iris-alt-screen-fix.patch`,
  `mods/dotfiles/.bashrc.d/0001_iris.bashrc`, `mods/dotfiles/iris/{config,theme}.toml`: deleted.
- `flake.lock`: regenerated, `iris` (and its transitive `flake-parts`/`nixpkgs`/`systems`) inputs
  pruned.
- `mods/shell.nix`: untouched — Atuin on its default Ctrl-R binding, no `--disable-ctrl-r`, no
  `atuin-bind` overrides.
- `WORKAROUNDS.md`: no IRIS entry.

Validation: `nix flake check` passes with IRIS removed.

---

## Re-adding later (when upstream fixes it)

Upstream issue [versenilvis/iris#138](https://github.com/versenilvis/iris/issues/138) is the
tracking issue. Re-add when either:

- upstream ships a fix that makes alt-screen suppression work for readline-invoked TUIs (the pgrp
  heuristic replaced or removed, and ideally chunk-split-proof smcup detection), or
- we accept carrying the local `overrideAttrs` patch again and re-verify it per IRIS version.

To re-add:

1. `flake.nix`: `iris.url = "github:versenilvis/iris/main";` (+ `nix flake lock --update-input iris`).
2. Restore `mods/iris.nix` **with the `homeManagerRelPath` fix** (do not reintroduce the
   `.config/home-manager` hardcode).
3. Restore `mods/dotfiles/.bashrc.d/0001_iris.bashrc`, `mods/dotfiles/iris/config.toml`,
   `mods/dotfiles/iris/theme.toml`.
4. Re-add `../../mods/iris.nix` to `homes/profiles/common.nix`.
5. If patching: regenerate the patch against the new pinned rev, re-check the `vendorHash`
   (patch does not change Go deps, so it should stay valid), and re-test the full interaction in
   a real tmux pane (not a programmatically-driven one) before switching.

Verification checklist (after a switch, in a fresh terminal):

1. `iris config show` → `toggle-mode = "ctrl+g"`.
2. `Ctrl-G` toggles IRIS mode; `Ctrl-R` opens Atuin (never toggles IRIS).
3. Type a partial command, then `Ctrl-R`; while filtering in Atuin, confirm no IRIS ghost
   text/suggestions appear and `Up`/`Down` move Atuin's selection.
4. Exit Atuin (`Esc`) → IRIS suggestions work again at the bash prompt.
