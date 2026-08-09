# Declarative Model-Runtime Model Management Design

**Status:** approved for planning
**Date:** 2026-07-27
**Scope:** new `mods/model-runtimes.nix` + `mods/dotfiles/model-runtimes/scripts/`, a shared `mods/dotfiles/scripts/lib/managed-state.js` (promoted from `agents/scripts/lib/`), and the darwin home profile that imports it

## Purpose

Manage which local LLM models are installed on a machine declaratively — pull
declared-but-missing, remove previously-managed-but-now-undeclared — regardless
of *which* model runtime that machine uses. Each machine runs exactly one
"ollama-compliant" runtime (ollama on Intel Macs, mlx-lm on Apple Silicon,
possibly others later); this module manages the model set for whichever one is
active on that host. It manages **models only** — installing/configuring the
runtime itself stays where it already lives (the brew/cask in
`darwin-base.nix`).

## The pattern (same as the agents Layer 2)

This is the identical shape to `mkPiPackageInstall`/`mkClaudePluginInstall` in
the agents system (see `docs/adr/0002-layered-asset-management.md`): the tool's
own installer owns opaque state, so revocation works by **tracked-state
diffing**. A backend-agnostic engine does the diff; per-backend **adapters**
(just three command strings each) supply the runtime-specific commands. The
engine never branches on backend internally — "shared utility, not shared
policy."

- **Engine** (`apply-models.js`, a near-copy of `apply-pi-packages.js`): reads
  the declared model list, the tracked state, and three adapter commands
  (`LIST_CMD`, `INSTALL_CMD`, `REMOVE_CMD`). Lists what's installed, installs
  declared-but-missing, removes **only tracked-but-undeclared** models (so a
  model the user pulled by hand is never touched), and writes the new state.
- **Adapters** (defined in `mods/model-runtimes.nix`, one per backend):

  | backend | LIST_CMD | INSTALL_CMD `<id>` | REMOVE_CMD `<id>` |
  |---|---|---|---|
  | ollama | `ollama list \| tail -n +2 \| awk '{print $1}'` | `ollama pull <id>` | `ollama rm <id>` |
  | mlx-lm | `mlx_lm.manage --scan` (parsed to repo ids) | `hf download <id>` | `mlx_lm.manage --delete --pattern <id>` (auto-confirmed) |

## Key decisions

- **Backend selection**: a single `modelRuntimes.backend` option (enum
  `ollama`/`mlx-lm`), defaulting by platform to match the runtime already
  installed — `aarch64-darwin → mlx-lm`, else `→ ollama`. A host overrides it
  in its own `homes/home-*.nix`. Platform-default keeps it declarative and
  predictable; the override covers the "this box is different" case. (One small
  option is fine — ADR 0002 rejected a broad *options layer*, not every option.)
- **Prune semantics**: tracked-state, not full ownership — only models this
  mechanism installed get removed when undeclared, mirroring the agents' Pi
  package behavior. Hand-pulled models survive. State in
  `~/.local/state/nix-models/<backend>.json`.
- **Model declaration**: per-backend lists (ids differ across runtimes —
  `qwen3:1.7b` vs `mlx-community/Qwen3-1.7B-4bit`), optionally machine-gated the
  same way agent assets use `isLoancrateMac`. The module manages only
  `declaredModels.${backend}`.
- **Shared state lib**: promote `managed-state.js` from
  `mods/dotfiles/agents/scripts/lib/` to `mods/dotfiles/scripts/lib/` so both
  the agents scripts and this one use one copy (atomic write + tracked-set
  read/write are generic, not agent-specific).
- **Both adapters in v1**: the engine is backend-agnostic, so ollama costs three
  extra command strings. mlx-lm is what the active Apple Silicon Macs run;
  ollama covers the Intel `maclab` and any future host.

## Runtime notes (CLI behavior confirmed from source)

Both CLIs were verified via context7 + upstream source (`ml-explore/mlx-lm`'s
`manage.py`, ollama's CLI docs), so the adapter commands are pinned, not
guessed:

- **mlx-lm has no download subcommand** — models fetch on first `load()`;
  declarative pre-pull uses `hf download <repo>` (huggingface_hub CLI), which
  populates the same cache `scan_cache_dir()` reads.
- **`mlx_lm.manage --scan`** prints a table: a `Scanning ... "mlx"` line, a
  `REPO ID` header, a dashes row, then rows. Repo ids are the only column-1
  tokens containing `/`, so `awk '$1 ~ "/"'` extracts them cleanly. Using
  `--pattern /` lists every cached repo (all HF ids contain `/`), so a declared
  id that isn't `mlx-community/*` is still seen as installed.
- **`mlx_lm.manage --delete --pattern <p>`** is a **substring** match over repo
  ids and prompts Y/N (empty = no). Pass the full repo id and auto-confirm with
  `yes | …`.
- **ollama**: `ollama pull`/`ollama rm`; `ollama list` is a
  `NAME ID SIZE MODIFIED` table → `tail -n +2 | awk '{print $1}'`. NAMEs carry
  the tag (`qwen3:1.7b`), so declare ids with explicit tags.

The one remaining on-device unknown is whether `hf`/`huggingface-cli` is on
PATH from the mlx-lm brew (a Task 3 check; add a brew if not).

- **Soft-fail under `set -eu`**: like the agents installers, guard the activation
  invocation so a failed pull/scan warns instead of aborting the whole switch,
  and (optionally) append to the agents convergence report's
  `${AGENTS_WARN_FILE:-/dev/null}` so it surfaces in that summary.

## Testing

- The engine gets a `node:test` suite mirroring `apply-pi-packages.test.cjs`:
  stub `list`/`install`/`remove` binaries, assert declared-missing get
  installed, tracked-undeclared get removed, hand-installed (untracked) survive,
  and state is written. Backend-agnostic — tested with a fake adapter.
- Re-run the existing agents script tests after the `managed-state.js` move to
  prove the promotion didn't break them.
- The Nix layer is verified by the existing `nix flake check` (forces the new
  activation entry's merged value).

## Non-Goals

- Not installing or configuring the runtime itself (ollama/mlx-lm) — "models
  only." The runtime install stays in `darwin-base.nix`.
- No full-ownership prune (won't delete hand-pulled models) — tracked-state
  only, matching the agents pattern.
- No unified cross-backend model catalog (ids are backend-specific; a shared
  `{ ollama = …; mlx = …; }` record is deferred until there's a real need).
- Not managing the remote `ollama.napisani.xyz` server (not in this flake).
- No NixOS/systemd variant in v1 (darwin home-activation only); the engine is
  reusable if a NixOS host later needs it.

## Recommendation

Ship as: (1) promote `managed-state.js` to a shared lib, (2) add the
backend-agnostic `apply-models.js` engine + tests, (3) add
`mods/model-runtimes.nix` with the backend option, per-backend adapters, and a
soft-failing home-activation step, (4) declare an initial per-backend model set
and wire the module into the darwin home profile.
