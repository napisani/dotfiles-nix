# Declarative Model-Runtime Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Declaratively manage the LLM models installed on each machine for
whichever local runtime it uses (ollama or mlx-lm) — pull declared, prune
previously-managed-but-undeclared — per
`docs/superpowers/specs/2026-07-27-declarative-model-runtimes-design.md`.

**Architecture:** A backend-agnostic diff-and-prune engine (`apply-models.js`,
modeled on `apply-pi-packages.js`) driven by per-backend adapter command
strings defined in `mods/model-runtimes.nix`. Backend is a platform-defaulted,
per-host-overridable option. Reuses the tracked-state machinery from the agents
system's `managed-state.js`.

**Tech Stack:** Nix (nix-darwin + home-manager, `home.activation`, `lib.mkOption`), Node.js with `node:test`, ollama CLI, mlx-lm (`mlx_lm.manage`) + `hf` (huggingface_hub).

## File Structure

- `mods/dotfiles/scripts/lib/managed-state.js` (moved from `agents/scripts/lib/`): shared atomic-write + tracked-set logic.
- `mods/dotfiles/agents/scripts/{apply-managed-json-keys,apply-managed-toml-keys,apply-claude-plugins,apply-pi-packages}.js`: `require` path updated to the shared lib.
- `mods/dotfiles/model-runtimes/scripts/apply-models.js` (+ `.test.cjs`): the backend-agnostic engine.
- `mods/model-runtimes.nix` (new): backend option, per-backend adapters, declared model lists, the soft-failing activation step.
- `homes/profiles/darwin.nix`: import the new module.

## Global Constraints

- Prefix all shell commands with `rtk`.
- Flakes only see tracked files: `rtk git add` new files before `nix flake check`/eval.
- `nix flake check` (the `checks.aarch64-darwin.activation-merge-forced` derivation) is the standing Nix verification; it forces the new activation entry's merged value.
- Node scripts stay standalone-testable via env vars, documented in each script's header, with a `.test.cjs` suite (`node --test`).
- Activation must not abort the whole switch on a failed pull/scan: soft-fail with a warning, matching the agents installers, and append to `${AGENTS_WARN_FILE:-/dev/null}`.
- Prune is tracked-state only — never remove a model this mechanism didn't install.
- Prerequisite: a clean working tree on a branch (this builds on the agents refactor branch or a fresh branch off it).

---

## Task 1: Promote `managed-state.js` to a shared lib

**Files:**
- Move: `mods/dotfiles/agents/scripts/lib/managed-state.js` → `mods/dotfiles/scripts/lib/managed-state.js`
- Modify: the four agents scripts that `require` it
- Test: existing agents `.test.cjs` suites (must still pass)

**Interfaces:**
- Produces: `mods/dotfiles/scripts/lib/managed-state.js` exporting `atomicWriteFileSync`, `readManagedState`, `writeManagedState` (unchanged API).

- [ ] **Step 1: Move the file**

```sh
rtk git mv mods/dotfiles/agents/scripts/lib/managed-state.js mods/dotfiles/scripts/lib/managed-state.js
```

- [ ] **Step 2: Update the four require paths**

In each of `apply-managed-json-keys.js`, `apply-managed-toml-keys.js`, `apply-claude-plugins.js`, `apply-pi-packages.js`, change:
```js
require("./lib/managed-state.js")
```
to:
```js
require("../../scripts/lib/managed-state.js")
```
(From `mods/dotfiles/agents/scripts/`, `../../scripts/lib` resolves to `mods/dotfiles/scripts/lib`.) Confirm every reference is updated: `rtk rg -n "lib/managed-state" mods/dotfiles/agents/scripts/`.

- [ ] **Step 3: Fix the isolated-`@iarna/toml` test's copy path**

`apply-managed-toml-keys.test.cjs` copies the script + `lib/managed-state.js` into a scratch dir to test the missing-dependency path. Update it to copy from the new shared location (`mods/dotfiles/scripts/lib/managed-state.js`) into the isolated dir's `lib/`, so the isolated script still resolves `../../scripts/lib/managed-state.js` — i.e. recreate that relative layout in the temp dir, or adjust the copy target to match the new require path.

- [ ] **Step 4: Run all agents script tests — must still pass**

Run:
```sh
for t in apply-managed-json-keys apply-managed-toml-keys apply-claude-plugins apply-pi-packages; do rtk node --test "mods/dotfiles/agents/scripts/$t.test.cjs"; done
```
Expected: 18/18 pass (5+5+4+4), no failures.

- [ ] **Step 5: Commit**

```sh
rtk git add -A
rtk git commit -m "refactor(scripts): promote managed-state.js to a shared lib"
```

## Task 2: The backend-agnostic `apply-models.js` engine (TDD)

**Files:**
- Create: `mods/dotfiles/model-runtimes/scripts/apply-models.js`
- Test: `mods/dotfiles/model-runtimes/scripts/apply-models.test.cjs`

**Interfaces:**
- Env contract: `DECLARED_MODELS` (JSON array of ids), `STATE_FILE`, `LIST_CMD` (prints installed ids, one per line), `INSTALL_CMD` and `REMOVE_CMD` (each run as `<cmd> <id>`), `BACKEND` (label for logs).
- Behavior: install `declared − installed`; remove `(state ∩ installed) − declared`; write state = declared. Tracked-state prune (never touches untracked installed models). Soft-fails per-model (a failed pull warns, doesn't abort the batch), exits 0 unless state is unreadable.

- [ ] **Step 1: Write the failing test**

```js
const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const SCRIPT = path.join(__dirname, "apply-models.js");

// A fake backend: LIST reads models.txt, INSTALL appends, REMOVE deletes a line.
function fakeAdapter(dir) {
  const store = path.join(dir, "models.txt");
  fs.writeFileSync(store, "");
  const list = path.join(dir, "list.sh");
  const install = path.join(dir, "install.sh");
  const remove = path.join(dir, "remove.sh");
  fs.writeFileSync(list, `#!/bin/sh\ncat ${store}\n`);
  fs.writeFileSync(install, `#!/bin/sh\necho "$1" >> ${store}\n`);
  fs.writeFileSync(remove, `#!/bin/sh\ngrep -vx "$1" ${store} > ${store}.tmp || true; mv ${store}.tmp ${store}\n`);
  for (const f of [list, install, remove]) fs.chmodSync(f, 0o755);
  return { store, list: `sh ${list}`, install: `sh ${install}`, remove: `sh ${remove}` };
}

function run(env) {
  return execFileSync(process.execPath, [SCRIPT], { env: { ...process.env, ...env }, encoding: "utf8" });
}

test("installs declared-missing and records them", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "models-"));
  const a = fakeAdapter(dir);
  run({
    BACKEND: "fake", DECLARED_MODELS: JSON.stringify(["m1", "m2"]),
    STATE_FILE: path.join(dir, "state.json"), LIST_CMD: a.list, INSTALL_CMD: a.install, REMOVE_CMD: a.remove,
  });
  assert.deepEqual(fs.readFileSync(a.store, "utf8").trim().split("\n").sort(), ["m1", "m2"]);
});

test("prunes only previously-managed models, leaving hand-installed ones", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "models-"));
  const a = fakeAdapter(dir);
  const state = path.join(dir, "state.json");
  // First run manages m1,m2.
  run({ BACKEND: "fake", DECLARED_MODELS: JSON.stringify(["m1", "m2"]), STATE_FILE: state, LIST_CMD: a.list, INSTALL_CMD: a.install, REMOVE_CMD: a.remove });
  // A hand-installed model appears out of band.
  fs.appendFileSync(a.store, "manual\n");
  // Second run declares only m1 → m2 pruned (tracked), manual survives (untracked).
  run({ BACKEND: "fake", DECLARED_MODELS: JSON.stringify(["m1"]), STATE_FILE: state, LIST_CMD: a.list, INSTALL_CMD: a.install, REMOVE_CMD: a.remove });
  assert.deepEqual(fs.readFileSync(a.store, "utf8").trim().split("\n").sort(), ["m1", "manual"]);
});
```

Run: `rtk node --test mods/dotfiles/model-runtimes/scripts/apply-models.test.cjs`
Expected: FAIL (script doesn't exist).

- [ ] **Step 2: Write the engine**

```js
// Declarative model management for a local LLM runtime. Backend-agnostic:
// the caller supplies LIST/INSTALL/REMOVE commands, so this never branches on
// which runtime it is. Tracked-state prune (like apply-pi-packages.js): only
// models this mechanism previously installed are removed when undeclared;
// hand-pulled models are never touched.
//
// Env: BACKEND, DECLARED_MODELS (JSON array), STATE_FILE, LIST_CMD (prints
// installed ids one per line), INSTALL_CMD/REMOVE_CMD (invoked as `<cmd> <id>`).

const { execSync } = require("node:child_process");
const { readManagedState, writeManagedState } = require("../../scripts/lib/managed-state.js");

const backend = process.env.BACKEND || "model-runtime";
const declared = JSON.parse(process.env.DECLARED_MODELS || "[]");
const stateFile = process.env.STATE_FILE;
const listCmd = process.env.LIST_CMD;
const installCmd = process.env.INSTALL_CMD;
const removeCmd = process.env.REMOVE_CMD;

function warn(msg) {
  console.error("model-runtimes: WARNING: " + msg);
  try {
    if (process.env.AGENTS_WARN_FILE) require("node:fs").appendFileSync(process.env.AGENTS_WARN_FILE, msg + "\n");
  } catch {}
}

let installed;
try {
  installed = new Set(execSync(listCmd, { encoding: "utf8" }).split("\n").map((s) => s.trim()).filter(Boolean));
} catch (e) {
  warn(backend + ": could not list installed models (" + e.message + ") — skipping this run");
  process.exit(0);
}

const { ok: stateOk, managed: previouslyManaged } = readManagedState(stateFile);
const declaredSet = new Set(declared);

for (const id of declared) {
  if (!installed.has(id)) {
    try { execSync(installCmd + " " + shq(id), { stdio: "inherit" }); }
    catch (e) { warn(backend + ": failed to install '" + id + "' (" + e.message + ")"); }
  }
}

if (stateOk) {
  for (const id of previouslyManaged) {
    if (!declaredSet.has(id) && installed.has(id)) {
      try { execSync(removeCmd + " " + shq(id), { stdio: "inherit" }); console.log("model-runtimes: removed undeclared '" + id + "'"); }
      catch (e) { warn(backend + ": failed to remove '" + id + "' (" + e.message + ")"); }
    }
  }
  writeManagedState(stateFile, declaredSet);
}

function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
```

Run: `rtk node --test mods/dotfiles/model-runtimes/scripts/apply-models.test.cjs`
Expected: PASS (both tests).

- [ ] **Step 3: Commit**

```sh
rtk git add -A
rtk git commit -m "feat(model-runtimes): backend-agnostic model diff-and-prune engine"
```

## Task 3: `mods/model-runtimes.nix` — backend option, adapters, activation

**Files:**
- Create: `mods/model-runtimes.nix`
- Modify: `homes/profiles/darwin.nix` (import it)

**Interfaces:**
- Produces: `options.modelRuntimes.backend` (enum, platform-defaulted) and `options.modelRuntimes.declaredModels` (attrset `{ ollama = [...]; mlx-lm = [...]; }`); a `home.activation.installModelRuntimeModels` step that runs the engine with the active backend's adapter commands and model list.
- Consumes: `apply-models.js` (Task 2), the active backend's CLI on PATH.

- [ ] **Step 1: Write the module**

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.modelRuntimes;
  dotfiles = "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles";
  nodeBin = "${pkgs.nodejs}/bin";   # match how other modules get node
  script = "${dotfiles}/model-runtimes/scripts/apply-models.js";
  stateFile = "${config.home.homeDirectory}/.local/state/nix-models/${cfg.backend}.json";

  # Per-backend adapters: three command strings, the only backend-specific bit.
  adapters = {
    ollama = {
      probe = "ollama";
      list = "ollama list | tail -n +2 | awk '{print $1}'";
      install = "ollama pull";
      remove = "ollama rm";
    };
    "mlx-lm" = {
      probe = "mlx_lm.manage";
      # scan output → bare repo ids; refine the parse against the real format.
      list = "mlx_lm.manage --scan 2>/dev/null | awk '/mlx/{print $1}'";
      install = "hf download";
      # confirm non-interactive delete flag against the installed version.
      remove = "yes | mlx_lm.manage --delete --pattern";
    };
  };
  a = adapters.${cfg.backend};
  models = cfg.declaredModels.${cfg.backend} or [ ];
in
{
  options.modelRuntimes = {
    backend = lib.mkOption {
      type = lib.types.enum [ "ollama" "mlx-lm" ];
      default = if pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.hostPlatform.isDarwin then "mlx-lm" else "ollama";
      description = "Local model runtime this host uses; models are managed for it.";
    };
    declaredModels = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = "Per-backend list of model ids to keep installed.";
    };
  };

  config.home.activation.installModelRuntimeModels = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"
    if command -v ${a.probe} >/dev/null 2>&1; then
      BACKEND=${lib.escapeShellArg cfg.backend} \
      DECLARED_MODELS=${lib.escapeShellArg (builtins.toJSON models)} \
      STATE_FILE=${lib.escapeShellArg stateFile} \
      LIST_CMD=${lib.escapeShellArg a.list} \
      INSTALL_CMD=${lib.escapeShellArg a.install} \
      REMOVE_CMD=${lib.escapeShellArg a.remove} \
        ${nodeBin}/node ${lib.escapeShellArg script} \
        || echo "model-runtimes: WARNING: model sync failed for ${cfg.backend} — continuing activation" >&2
    else
      echo "model-runtimes: ${a.probe} not found — skipping model sync for ${cfg.backend}" >&2
    fi
  '';
}
```

Note: match `nodeBin` to how sibling modules obtain node (they use `pkgs-unstable.nodejs`); adjust the module args accordingly if this profile passes `pkgs-unstable`.

- [ ] **Step 2: Import into the darwin home profile**

Add `../mods/model-runtimes.nix` (correct relative path) to the imports list in `homes/profiles/darwin.nix`.

- [ ] **Step 3: Verify PATH availability of the mlx-lm tools**

On an Apple Silicon Mac after the mlx-lm brew is installed, confirm `mlx_lm.manage` and `hf` are on PATH:
```sh
command -v mlx_lm.manage hf
```
If `hf`/`huggingface-cli` is missing, add it to `brews` in `darwin-base.nix` (guarded to aarch64) and note it. Also confirm `mlx_lm.manage --scan` output format and `--delete` confirmation behavior, and adjust the adapter's `list`/`remove` strings to match.

- [ ] **Step 4: Flake check**

```sh
rtk git add -A
rtk nix build '.#checks.aarch64-darwin.activation-merge-forced'
```
Expected: builds clean (the new activation entry's `.data` forces without error).

- [ ] **Step 5: Commit**

```sh
rtk git commit -m "feat(model-runtimes): backend option, adapters, soft-failing activation step"
```

## Task 4: Declare an initial model set and verify selection

**Files:**
- Modify: `mods/model-runtimes.nix` (or a machine's `homes/home-*.nix`) to set `modelRuntimes.declaredModels`

**Interfaces:**
- Consumes: the option from Task 3.

- [ ] **Step 1: Declare models per backend**

Seed from the models already referenced in the scute configs, mapped per backend:
```nix
modelRuntimes.declaredModels = {
  ollama = [ "qwen3:1.7b" "qwen2.5-coder:14b" ];
  mlx-lm = [ "mlx-community/Qwen3-1.7B-4bit" ];  # confirm exact repo ids exist
};
```
Verify each mlx-lm repo id resolves on the Hub before declaring (a wrong id fails at `hf download` time, not eval time).

- [ ] **Step 2: Verify backend selection resolves per machine**

```sh
rtk nix eval '.#darwinConfigurations."nicks-mbp".config.home-manager.users.nick.modelRuntimes.backend'      # expect "mlx-lm"
```
And confirm the activation entry embeds the mlx-lm model list on that machine:
```sh
rtk nix eval --raw '.#darwinConfigurations."nicks-mbp".config.home-manager.users.nick.home.activation.installModelRuntimeModels.data' | grep -c "mlx-community"
```
Expected: backend is `mlx-lm`; grep ≥ 1.

- [ ] **Step 3: End-to-end dry check of the engine against the real backend (optional, on-device)**

On an Apple Silicon Mac, run the engine by hand with a one-model declared list pointed at a scratch state file, confirm it pulls and records, then re-run with an empty list and confirm it removes only that model. This exercises the real mlx-lm adapter before trusting it in activation.

- [ ] **Step 4: Commit**

```sh
rtk git add -A
rtk git commit -m "feat(model-runtimes): declare initial per-backend model set"
```

## Task 5: Documentation

**Files:**
- Modify: `CONTEXT.md` (glossary: "Model runtime backend"), and either extend the `agent-management` skill or add a short note pointing at this module as a sibling Layer-2 mechanism.

- [ ] **Step 1: Document the mechanism**

Add a `CONTEXT.md` glossary entry describing the model-runtime backend selection and that model management is a Layer-2 tracked-state mechanism outside the agents domain. Cross-reference `docs/adr/0002-layered-asset-management.md` (the pattern) — optionally add ADR `0003-declarative-model-runtimes.md` if the backend-adapter decision warrants it.

- [ ] **Step 2: Commit**

```sh
rtk git add -A
rtk git commit -m "docs(model-runtimes): document backend selection and the Layer-2 model manager"
```

## Risks / contingencies

- **mlx-lm CLI surface** (scan format, delete confirmation, `hf` availability) is the biggest unknown — Task 3 Step 3 verifies it on-device before trusting it. If `mlx_lm.manage --delete` can't be made non-interactive, fall back to removing the model's HF cache dir directly (`hf` cache path) as the REMOVE_CMD.
- **`hf download` for a wrong repo id** fails at activation, not eval — the soft-fail guard keeps it from aborting the switch; the warning surfaces via the report.
- **Backend override** for a host that doesn't match its arch default is a one-line `modelRuntimes.backend = "…";` in that host's home file.
