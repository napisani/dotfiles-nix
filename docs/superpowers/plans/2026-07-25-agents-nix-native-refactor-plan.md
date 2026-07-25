# Agents Nix-Native Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move every agent asset that only Nix writes onto pure Nix
mechanisms (flake inputs + `home.file`), simplify the config-merge layer to
full key ownership, add eval-time and activation-time safety nets, and
document the resulting three-layer model, per
`docs/superpowers/specs/2026-07-25-agents-nix-native-refactor-design.md`.

**Architecture:** Assets sort into three layers by "who else writes this
path" (see the design doc's "The Sorting Question"): Layer 0 becomes
`home.file` backed by pinned flake inputs or `mkOutOfStoreSymlink`; Layer 1
keeps activation-time merges but owns the whole managed key; Layer 2
(Claude plugins, Pi packages, rtk) is untouched. The in-repo precedent for
Layer 0 is `mods/opencode.nix`.

**Tech Stack:** Nix flakes, nix-darwin, home-manager (`home.file`, `mkOutOfStoreSymlink`, `lib.hm.dag`), Node.js scripts under `mods/dotfiles/agents/scripts/` with `node:test`.

## File Structure

- `flake.nix`: `checks` output; `roles` per machine; 17 skill-source inputs.
- `lib/builders.nix`: thread `roles` → `machineRoles` specialArg.
- `mods/agents/lib.nix`: roles-derived gating, shared agentmemory facts, `mkLocalFileLinks`, `inputs`/`machineRoles` threading.
- `mods/agents/skills.nix`: catalog gains `input` + per-skill `path`; `mkCommunitySkillFiles`/`mkLocalSkillFiles`; wipe-and-rebuild machinery deleted at the end.
- `mods/agents/{claude,codex,opencode,pi}.nix`: per-agent cutover to `home.file`; DAG re-anchoring; opencode absorbs `mods/opencode.nix`.
- `mods/agents/shared-store.nix` (new): owns `~/.agents/skills`.
- `mods/agents/report.nix` (new): activation warning report.
- `mods/agents/managed-config-lib.nix` + `mods/dotfiles/agents/scripts/apply-managed-{json,toml}-keys.js` (+ tests): full key ownership.
- `mods/npmx.nix`: drop `skills@latest`.
- `mods/dotfiles/agents/shared-skills/agent-management/SKILL.md`, `CONTEXT.md`, `docs/adr/0002-layered-asset-management.md`: documentation.

## Global Constraints

- Prefix all shell commands with `rtk` (e.g. `rtk nix flake check`, `rtk git commit`).
- Flakes only see git-tracked files: `rtk git add <new-file>` before any `nix eval`/`nix flake check` that must see it (staging is enough).
- Machine gating derives from flake-declared metadata (specialArgs), never `MACHINE_NAME` (a shell-runtime `home.sessionVariables` string).
- The one rule from `docs/adr/0001-per-agent-modules.md` still applies: shared *utilities* (parameterized by path/ID) are fine; shared *scripts that branch on agent identity* are not.
- Node scripts must stay standalone-testable with env vars (documented in each script's header comment).
- **Prerequisite:** the working tree must be clean before Task 1 — the current in-flight refactor work must be committed first. Run `rtk git status` and land or stash anything outstanding.
- The `nix flake check` added in Task 1 is the standing verification for every subsequent task; "flake check passes" always means `rtk nix flake check` from the repo root.
- Superseded suggestion, deliberately not in this plan: making the old wipe-then-fetch skill install non-destructive (temp-dir + swap). Phase 3 deletes that mechanism entirely, so hardening it first would be wasted work.

---

## Phase 1: Safety net

### Task 1: Flake check that forces all merged activation values

**Files:**
- Modify: `flake.nix` (add a `checks` output after `nixosConfigurations`)

**Interfaces:**
- Produces: `checks.aarch64-darwin.activation-merge-forced` — the derivation every later task's verification relies on via `rtk nix flake check`.

This is the automated version of the manual recipe in the `agent-management` skill's "Verifying a change actually works" section. It forces `system.activationScripts.script.text` (what `darwin-rebuild switch` itself evaluates) for all three darwin machines, plus every `home.activation.<name>.data` merged value for all four configurations — the exact evaluation that exploded in the real `fixOpencodePathConflicts` collision.

- [ ] **Step 1: Write the check (expecting to prove it catches collisions before trusting it)**

Add to `flake.nix` inside the outputs attrset, after `nixosConfigurations`:

```nix
checks.aarch64-darwin.activation-merge-forced =
  let
    pkgs = nixpkgs.legacyPackages.aarch64-darwin;
    forceDarwinScript =
      name:
      builtins.stringLength
        self.darwinConfigurations.${name}.config.system.activationScripts.script.text;
    forceHomeActivation =
      cfg:
      let
        acts = cfg.config.home-manager.users.nick.home.activation;
      in
      lib.foldl' (sum: n: sum + builtins.stringLength acts.${n}.data) 0 (builtins.attrNames acts);
    total = lib.foldl' (a: b: a + b) 0 (
      map forceDarwinScript (builtins.attrNames self.darwinConfigurations)
      ++ map (n: forceHomeActivation self.darwinConfigurations.${n}) (
        builtins.attrNames self.darwinConfigurations
      )
      ++ map (n: forceHomeActivation self.nixosConfigurations.${n}) (
        builtins.attrNames self.nixosConfigurations
      )
    );
  in
  pkgs.runCommand "activation-merge-forced-${toString total}" { } "echo ${toString total} > $out";
```

- [ ] **Step 2: Sabotage-test — inject a known collision and verify the check fails**

Temporarily add to `mods/agents/claude.nix`'s returned attrset:

```nix
home.activation.fixOpencodePathConflicts = lib.hm.dag.entryBefore [ "linkGeneration" ] "echo collision";
```

Run: `rtk nix flake check`
Expected: FAIL with `conflicting definition values` mentioning `home.activation.fixOpencodePathConflicts`.

- [ ] **Step 3: Remove the sabotage and verify the check passes**

Delete the injected entry from `mods/agents/claude.nix`.
Run: `rtk nix flake check`
Expected: PASS (builds the trivial `activation-merge-forced-<N>` derivation).

- [ ] **Step 4: Commit**

```bash
rtk git add flake.nix
rtk git commit -m "feat(checks): flake check forcing all merged activation values"
```

---

## Phase 2: Small structural fixes

### Task 2: Machine roles via specialArgs (replace hostname string-compares)

**Files:**
- Modify: `flake.nix` (add `roles` per machine)
- Modify: `lib/builders.nix` (thread `roles` → `machineRoles` specialArg)
- Modify: `mods/agents/lib.nix` (accept `machineRoles`, derive `isLoancrateMac` from it, thread through `callAgentLib`)
- Modify: every file under `mods/agents/` that imports `./lib.nix` (pass `machineRoles` through)

**Interfaces:**
- Produces: `machineRoles` (list of strings) as a home-manager specialArg on every configuration; `shared.isLoancrateMac` now means `builtins.elem "loancrate" machineRoles`.
- Consumes: nothing from other tasks.

Why: `isLoancrateMac = hostname == "Nicks-Loancrate-MacBook-Pro"` fails *silently* — rename the machine in `flake.nix` and every gated asset just stops installing with no error. Roles travel with the machine definition, so a rename can't desynchronize them.

- [ ] **Step 1: Add roles to each machine in `flake.nix`**

```nix
"nicks-mbp" = builders.mkDarwinSystem {
  system = "aarch64-darwin";
  hostname = "nicks-mbp";
  username = "nick";
  roles = [ "personal" ];
  modules = [ ./systems/profiles/darwin-personal.nix ];
  homeModules = [ ./homes/home-nicks-mbp.nix ];
};
```

Same pattern for the others: `Nicks-Loancrate-MacBook-Pro` gets `roles = [ "work" "loancrate" ];`, `maclab` gets `roles = [ "lab" ];`, `supermicro` gets `roles = [ "server" ];`.

- [ ] **Step 2: Thread roles through `lib/builders.nix`**

Change `mkSpecialArgs` to take and expose roles:

```nix
mkSpecialArgs = system: hostname: roles: {
  inherit inputs hostname;
  machineRoles = roles;
  pkgs-unstable = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  # ... rest unchanged ...
};
```

`mkDarwinSystem` and `mkNixOSSystem` each gain `roles ? [ ],` in their argument set and call `mkSpecialArgs system hostname roles`. In `mkNixOSSystem`, also add `machineRoles = roles;` to the top-level `specialArgs` attrset (alongside `inherit inputs hostname;`).

- [ ] **Step 3: Derive the boolean from roles in `mods/agents/lib.nix`**

Add `machineRoles ? [ ],` to the function signature (it has no `...`, so this is required), replace the hostname comparison:

```nix
# Machine gating: derived from the flake-declared roles list (passed as a
# specialArg from flake.nix's own machine definitions). Role-based rather
# than hostname-string-based so renaming a machine in flake.nix can't
# silently turn every gated asset off — the roles travel with the machine.
isLoancrateMac = builtins.elem "loancrate" machineRoles;
```

and thread it through `callAgentLib`:

```nix
callAgentLib = path: import path { inherit config lib pkgs-unstable hostname machineRoles; };
```

- [ ] **Step 4: Update every `import ./lib.nix` call site**

Run: `rtk rg -n "import ./lib.nix" mods/agents/`
For each hit (claude.nix, codex.nix, opencode.nix, pi.nix, skills.nix, instructions.nix, managed-config-lib.nix, and any other): add `machineRoles ? [ ],` to that file's own function signature and change the import to `import ./lib.nix { inherit config lib pkgs-unstable hostname machineRoles; }`. Also update `lib.nix`'s own header usage comment.

- [ ] **Step 5: Verify gating still resolves per machine**

Run:
```bash
rtk nix flake check
rtk nix eval '.#darwinConfigurations."Nicks-Loancrate-MacBook-Pro".config.system.activationScripts.script.text' --raw | grep -c loancrate-pr-workflow
rtk nix eval '.#darwinConfigurations."nicks-mbp".config.system.activationScripts.script.text' --raw | grep -c loancrate-pr-workflow
```
Expected: flake check passes; first grep prints ≥ 1; second grep prints 0 (grep exits 1 — that's the pass condition).

- [ ] **Step 6: Commit**

```bash
rtk git add flake.nix lib/builders.nix mods/agents/
rtk git commit -m "refactor(agents): machine gating via flake-declared roles, not hostname strings"
```

### Task 3: Hoist shared agentmemory facts into lib.nix

**Files:**
- Modify: `mods/agents/lib.nix` (add + export two facts)
- Modify: `mods/agents/claude.nix`, `mods/agents/codex.nix`, `mods/agents/pi.nix` (consume them)

**Interfaces:**
- Produces: `shared.agentmemoryMcpBin` (string path) and `shared.agentmemoryUrl` (string URL).

Why: the bin path and URL are agent-blind *facts* currently copy-pasted into three files — changing the port means three edits. The per-agent *shapes* (Pi's `lifecycle = "lazy"`, etc.) stay local, matching how the skills catalog already shares data without sharing policy.

- [ ] **Step 1: Add the facts to `mods/agents/lib.nix`**

In the `let` block (after `gitBin`):

```nix
# agentmemory MCP server facts, shared by claude/codex/pi's own MCP
# declarations. The binary is installed globally by mods/npmx.nix
# (`npm install -g @agentmemory/mcp`), not spawned via npx.
agentmemoryMcpBin = "${home}/.local/bin/agentmemory-mcp";
agentmemoryUrl = "http://localhost:3111";
```

Add both names to the `inherit (...)` export list.

- [ ] **Step 2: Consume in the three agent files**

In each of `claude.nix`, `codex.nix`, `pi.nix`: delete the local `agentmemoryMcpBin = ...` binding (and its comment), and in the agentmemory MCP entry use `command = shared.agentmemoryMcpBin;` and `env.AGENTMEMORY_URL = shared.agentmemoryUrl;` (add `agentmemoryMcpBin`-free `inherit` adjustments as needed — reference via `shared.` to keep it obvious the fact is shared).

- [ ] **Step 3: Verify**

Run:
```bash
rtk nix flake check
rtk nix eval '.#darwinConfigurations."nicks-mbp".config.system.activationScripts.script.text' --raw | grep -c "agentmemory-mcp"
```
Expected: flake check passes; grep count unchanged from before the edit (same number of occurrences — capture it before editing with the same command).

- [ ] **Step 4: Commit**

```bash
rtk git add mods/agents/
rtk git commit -m "refactor(agents): hoist shared agentmemory facts into lib.nix"
```

---

## Phase 3: Layer 0 migration — skills to pure Nix

### Task 4: Add flake inputs for every community skill repo

**Files:**
- Modify: `flake.nix` (17 new inputs; `proctmux` already exists and is reused)

**Interfaces:**
- Produces: `inputs.<name>` source trees for Task 5's catalog. Names below are load-bearing — Task 5 references them exactly.

- [ ] **Step 1: Add the inputs**

In `flake.nix` inputs, after the existing custom packages:

```nix
# ── Community skill sources (content-only, pinned via flake.lock) ──────
# Consumed by mods/agents/skills.nix's catalog. Update with:
#   nix flake update <input-name>
anthropic-skills = { url = "github:anthropics/skills"; flake = false; };
intellectronica-agent-skills = { url = "github:intellectronica/agent-skills"; flake = false; };
addyosmani-agent-skills = { url = "github:addyosmani/agent-skills"; flake = false; };
superpowers = { url = "github:obra/superpowers"; flake = false; };
mattpocock-skills = { url = "github:mattpocock/skills"; flake = false; };
arjunmahishi-dotfiles = { url = "github:arjunmahishi/dotfiles"; flake = false; };
vantage-nvim-skills = { url = "github:napisani/vantage-nvim"; flake = false; };
playwright-cli-skills = { url = "github:microsoft/playwright-cli"; flake = false; };
deepagents = { url = "github:langchain-ai/deepagents"; flake = false; };
softaworks-agent-toolkit = { url = "github:softaworks/agent-toolkit"; flake = false; };
understand-anything = { url = "github:Lum1104/Understand-Anything"; flake = false; };
workmux-skills = { url = "github:raine/workmux"; flake = false; };
agentmemory-skills = { url = "github:rohitg00/agentmemory"; flake = false; };
gh-stack-skills = { url = "github:github/gh-stack"; flake = false; };
no-ai-slop = { url = "github:petergyang/no-ai-slop"; flake = false; };
private-skills = { url = "git+ssh://git@github.com/napisani/private-skills"; flake = false; };
lc-script-skills = { url = "github:napisani/lc-script"; flake = false; };
```

Notes: `proctmux` skills come from the existing `proctmux` input (a flake input's `outPath` is its source tree — works the same). If `lc-script` turns out to be private, switch it to the `git+ssh://` form like `private-skills`. The old catalog's `fullDepth` flag existed for the `skills` CLI's shallow-clone behavior and has no meaning for flake inputs — it disappears.

- [ ] **Step 2: Lock and verify**

Run: `rtk nix flake lock && rtk nix flake metadata | head -40`
Expected: lock succeeds (SSH agent must be available for `private-skills`); all new inputs listed. Then `rtk nix flake check` still passes.

- [ ] **Step 3: Commit**

```bash
rtk git add flake.nix flake.lock
rtk git commit -m "feat(agents): pin community skill repos as flake inputs"
```

### Task 5: Restructure the catalog and add the home.file generators

**Files:**
- Modify: `mods/agents/skills.nix` (catalog entries gain `input` + per-skill `path`; add `mkCommunitySkillFiles`, `mkLocalSkillFiles`; export them)
- Modify: `mods/agents/lib.nix` (add `mkLocalFileLinks`; thread `inputs` through `callAgentLib`)
- Modify: each `mods/agents/*.nix` module signature to destructure `inputs` (they receive it as a specialArg already)

**Interfaces:**
- Produces:
  - `skills.mkCommunitySkillFiles { agentId, skillDirRelPath }` → home.file attrset (store symlinks, `force = true`)
  - `skills.mkLocalSkillFiles { sourceRelPath, targetDirRelPath }` → home.file attrset (out-of-store symlinks per directory, `force = true`)
  - `shared.mkLocalFileLinks { sourceRelPath, targetDirRelPath, extensions }` → home.file attrset (out-of-store symlinks per file, excluding `*.test.*`, `force = true`)
  - Catalog entry shape: `{ input = inputs.<name>; skills = [ { name = "..."; path = "relative/dir/in/repo"; } ... ]; agents = [...]; condition ? true; }`
- Consumes: Task 4's input names.

Nothing consumes the new helpers yet — the old `mkAgentSkillInstall` keeps working off the same entries during Tasks 6–9 is NOT possible once the shape changes, so this task also deletes `mkCommunitySkillCmd`'s consumption *only after* confirming shape compatibility: keep `mkAgentSkillInstall` compiling by updating `mkCommunitySkillCmd` to a stub is wrong. Instead: this task changes the catalog shape AND updates `mkCommunitySkillCmd` to consume the new shape via the store path (`skills add "${source.input}" ... --skill <name>`), so the old mechanism keeps functioning (now offline, from pinned store paths) until each agent cuts over in Tasks 6–9. This is the migration's compatibility bridge.

- [ ] **Step 1: Discover each skill's in-repo path**

```bash
rtk nix flake lock
for i in anthropic-skills intellectronica-agent-skills addyosmani-agent-skills superpowers \
         mattpocock-skills arjunmahishi-dotfiles proctmux vantage-nvim-skills \
         playwright-cli-skills deepagents softaworks-agent-toolkit understand-anything \
         workmux-skills agentmemory-skills gh-stack-skills no-ai-slop private-skills lc-script-skills; do
  p=$(rtk nix eval --impure --raw --expr "(builtins.getFlake (toString ./.)).inputs.$i.outPath")
  echo "== $i"
  find "$p" -name SKILL.md -maxdepth 6 | sed "s|$p/||"
done
```

Record the directory (parent of each SKILL.md) for every skill named in the current catalog. Cross-check ambiguous matches by grepping the frontmatter: `grep -l '^name: <skill-name>' <candidates>`.

- [ ] **Step 2: Rewrite the catalog entries**

Each entry in `agentSkillSources` becomes (example):

```nix
{
  input = inputs.superpowers;
  skills = [
    { name = "brainstorming"; path = "skills/brainstorming"; }
    { name = "systematic-debugging"; path = "skills/systematic-debugging"; }
  ];
  agents = allAgents;
}
```

Fill `path` from Step 1's output for all ~40 skills. Keep `condition = isLoancrateMac` on the two Loancrate entries.

- [ ] **Step 3: Update `mkCommunitySkillCmd` as the compatibility bridge**

```nix
mkCommunitySkillCmd =
  agentId: source:
  let
    skillArgs = builtins.concatStringsSep " " (
      map (s: "--skill ${lib.escapeShellArg s.name}") source.skills
    );
  in
  "skills add ${lib.escapeShellArg "${source.input}"} --global --agent ${lib.escapeShellArg agentId} --yes --copy ${skillArgs}";
```

(Points the CLI at the pinned store path instead of the network URL; drops `fullDepth`.)

- [ ] **Step 4: Add the generators**

In `skills.nix`:

```nix
# home.file attrset installing this agent's community skills as store
# symlinks. Replaces wipe-and-rebuild `skills add`: revocation is now
# home-manager's own link bookkeeping (drop the catalog entry → link is
# removed on next switch), content is pinned by flake.lock, and activation
# needs no network. force=true so pre-migration copied directories (and any
# stray writes into a skill dir) are replaced, preserving the old
# wipe-and-rebuild semantics of "Nix owns this directory".
mkCommunitySkillFiles =
  { agentId, skillDirRelPath }:
  builtins.listToAttrs (
    lib.concatMap (
      source:
      map (s: {
        name = "${skillDirRelPath}/${s.name}";
        value = {
          source = "${source.input}/${s.path}";
          force = true;
        };
      }) source.skills
    ) (builtins.filter (s: builtins.elem agentId (s.agents or [ ])) enabledSkillSources)
  );

# home.file attrset linking every skill directory under a dotfiles subdir
# into targetDirRelPath as out-of-store symlinks: edits to files under
# mods/dotfiles are live immediately (no rebuild), while adding/removing a
# whole directory needs a switch (the entry set is enumerated at eval time
# from the flake's own tracked tree).
mkLocalSkillFiles =
  { sourceRelPath, targetDirRelPath }:
  let
    names = lib.attrNames (
      lib.filterAttrs (_: t: t == "directory") (builtins.readDir (../dotfiles + "/${sourceRelPath}"))
    );
  in
  builtins.listToAttrs (
    map (name: {
      name = "${targetDirRelPath}/${name}";
      value = {
        source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${sourceRelPath}/${name}";
        force = true;
      };
    }) names
  );
```

Export both. In `lib.nix`, add the agent-blind file-level variant (for Pi extensions/themes):

```nix
# Link every regular file with one of `extensions` under a dotfiles subdir
# as an out-of-store symlink (live-editable), excluding *.test.* files.
mkLocalFileLinks =
  { sourceRelPath, targetDirRelPath, extensions }:
  let
    ok =
      name: type:
      type == "regular"
      && lib.any (ext: lib.hasSuffix ext name) extensions
      && !(lib.hasInfix ".test." name);
    names = lib.attrNames (lib.filterAttrs ok (builtins.readDir (../dotfiles + "/${sourceRelPath}")));
  in
  builtins.listToAttrs (
    map (name: {
      name = "${targetDirRelPath}/${name}";
      value = {
        source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${sourceRelPath}/${name}";
        force = true;
      };
    }) names
  );
```

Export it. Thread `inputs` through: `callAgentLib = path: import path { inherit config lib pkgs-unstable hostname machineRoles inputs; };`, add `inputs ? { },` to `lib.nix` and `skills.nix` signatures, and destructure `inputs` in each agent module that will pass it (they all receive it as a specialArg; the direct `import ./lib.nix { ... }` calls in each module gain `inputs` too).

- [ ] **Step 5: Verify the bridge still works end-to-end**

```bash
rtk nix flake check
rtk nix eval '.#darwinConfigurations."nicks-mbp".config.system.activationScripts.script.text' --raw | grep "skills add /nix/store" | head -3
```
Expected: flake check passes; the activation script now invokes `skills add` against `/nix/store/...` paths (offline, pinned).

- [ ] **Step 6: Commit**

```bash
rtk git add flake.nix mods/agents/
rtk git commit -m "refactor(agents): catalog gains pinned inputs + per-skill paths; add home.file generators"
```

### Task 6: Cut Claude Code over to home.file

**Files:**
- Modify: `mods/agents/claude.nix`

**Interfaces:**
- Consumes: `skills.mkCommunitySkillFiles`, `skills.mkLocalSkillFiles` (Task 5).

- [ ] **Step 1: Replace the activation installs with home.file**

In `claude.nix`, delete `home.activation.installClaudeSkills` and `home.activation.installClaudeCommands` entirely, and add:

```nix
home.file =
  skills.mkCommunitySkillFiles {
    agentId = "claude-code";
    skillDirRelPath = ".claude/skills";
  }
  // skills.mkLocalSkillFiles {
    sourceRelPath = "agents/shared-skills";
    targetDirRelPath = ".claude/skills";
  }
  // skills.mkLocalSkillFiles {
    sourceRelPath = "agents/claude/skills";
    targetDirRelPath = ".claude/skills";
  }
  // skills.mkLocalSkillFiles {
    sourceRelPath = "agents/claude/commands";
    targetDirRelPath = ".claude/commands";
  };
```

- [ ] **Step 2: Re-anchor the DAG references**

Every `entryAfter [ "installClaudeSkills" ]` in `claude.nix` (`installClaudeRtkHooks`, `configureClaudeMcpServers`, `installClaudePlugins`, `applyClaudeWorkmuxHooks`) becomes `entryAfter [ "linkGeneration" ]`. Remove `skillDir` and `commandsDir` from `fixClaudePathConflicts`'s path list (keep `"${home}/.agents/skills"` — Task 10 removes it). Keep the `skillDir`/`commandsDir` let-bindings only if still referenced; otherwise delete them.

- [ ] **Step 3: One-time cleanup of pre-migration copies, then switch**

The old mechanism `--copy`'d real directories; `force = true` replaces them, but clear them anyway so nothing stale survives the transition (everything in these dirs is Nix-installed today by the wipe-and-rebuild mechanism, so this deletes nothing hand-made):

```bash
rm -rf ~/.claude/skills/* ~/.claude/commands/*
rtk git add mods/agents/claude.nix
rtk nix flake check
sudo darwin-rebuild switch --flake ~/.config/home-manager
```

- [ ] **Step 4: Verify**

```bash
ls -la ~/.claude/skills | head -20
readlink ~/.claude/skills/skill-creator
readlink ~/.claude/skills/agent-management
ls -la ~/.claude/commands | head
```
Expected: community skills are symlinks into `/nix/store/...`; local/shared skills are symlinks into `~/.config/home-manager/mods/dotfiles/...`. Smoke test: start `claude` and confirm a community skill (e.g. skill-creator) and a local skill both appear/load. If Claude rejects read-only store symlinks (it should not — it already followed the old mechanism's local-skill symlinks), fall back to `recursive = true` copies for community entries and note it in the commit message.

- [ ] **Step 5: Commit**

```bash
rtk git add mods/agents/claude.nix
rtk git commit -m "refactor(claude): skills and commands via home.file, drop activation installs"
```

### Task 7: Cut Codex over to home.file

**Files:**
- Modify: `mods/agents/codex.nix`

Same shape as Task 6 with Codex's paths, plus one Codex-specific caveat: the old reset deliberately preserved hidden entries (`.system`) in `~/.codex/skills` — the manual cleanup must too.

- [ ] **Step 1: Replace activation install with home.file**

Delete `home.activation.installCodexSkills`; add:

```nix
home.file =
  skills.mkCommunitySkillFiles {
    agentId = "codex";
    skillDirRelPath = ".codex/skills";
  }
  // skills.mkLocalSkillFiles {
    sourceRelPath = "agents/shared-skills";
    targetDirRelPath = ".codex/skills";
  }
  // skills.mkLocalSkillFiles {
    sourceRelPath = "agents/codex/skills";
    targetDirRelPath = ".codex/skills";
  };
```

Re-anchor `installCodexRtkHooks` and `configureCodexMcpServers` from `entryAfter [ "installCodexSkills" ]` to `entryAfter [ "linkGeneration" ]`. Remove `skillDir` from `fixCodexPathConflicts` (that leaves its list empty — delete the whole `fixCodexPathConflicts` entry).

- [ ] **Step 2: Cleanup (preserving hidden entries), switch, verify**

```bash
find ~/.codex/skills -mindepth 1 -maxdepth 1 ! -name '.*' -exec rm -rf {} +
rtk git add mods/agents/codex.nix
rtk nix flake check
sudo darwin-rebuild switch --flake ~/.config/home-manager
ls -la ~/.codex/skills | head -20
```
Expected: store/dotfiles symlinks as in Task 6; `.system` (if present) untouched. Smoke test Codex loads a skill.

- [ ] **Step 3: Commit**

```bash
rtk git add mods/agents/codex.nix
rtk git commit -m "refactor(codex): skills via home.file, drop activation install"
```

### Task 8: Cut OpenCode over to home.file

**Files:**
- Modify: `mods/agents/opencode.nix`

- [ ] **Step 1: Replace activation install with home.file**

Delete `home.activation.installOpencodeSkills` and `home.activation.fixOpencodeSkillPathConflicts` (home.file `force` handles stale paths); add:

```nix
home.file =
  skills.mkCommunitySkillFiles {
    agentId = "opencode";
    skillDirRelPath = ".config/opencode/skills";
  }
  // skills.mkLocalSkillFiles {
    sourceRelPath = "agents/shared-skills";
    targetDirRelPath = ".config/opencode/skills";
  }
  // skills.mkLocalSkillFiles {
    sourceRelPath = "agents/opencode/skills";
    targetDirRelPath = ".config/opencode/skills";
  };
```

Re-anchor `installOpencodeRtkHooks` to `entryAfter [ "linkGeneration" ]`. Note: `mods/opencode.nix` (sibling) already links `.config/opencode/skills/local` — no catalog skill is named `local`, so there is no entry collision; the header comment about the old naming collision can shrink but full consolidation waits for Task 11.

- [ ] **Step 2: Cleanup, switch, verify**

```bash
find ~/.config/opencode/skills -mindepth 1 -maxdepth 1 ! -name local -exec rm -rf {} +
rtk git add mods/agents/opencode.nix
rtk nix flake check
sudo darwin-rebuild switch --flake ~/.config/home-manager
ls -la ~/.config/opencode/skills | head -20
```
Expected: symlinked skills plus the pre-existing `local` symlink. Smoke test OpenCode.

- [ ] **Step 3: Commit**

```bash
rtk git add mods/agents/opencode.nix
rtk git commit -m "refactor(opencode): skills via home.file, drop activation install"
```

### Task 9: Cut Pi over to home.file (skills, extensions, themes)

**Files:**
- Modify: `mods/agents/pi.nix`

Pi differs in two ways: shared local skills are deliberately NOT linked into `~/.pi/agent/skills` (Pi auto-discovers `~/.agents/skills`, which Task 10 converts — this replaces today's install-then-dedupe dance), and extensions/themes are file-level links.

- [ ] **Step 1: Replace activation installs with home.file**

Delete `home.activation.installPiSkills`, `home.activation.dedupePiGlobalSkills`, the `syncPiExtensions`, `syncPiThemes`, and `removePiGlobalSkillDuplicates` let-bindings, and the `${syncPiExtensions}`/`${syncPiThemes}` lines inside `installPiConfig`. Add:

```nix
home.file =
  skills.mkCommunitySkillFiles {
    agentId = "pi";
    skillDirRelPath = ".pi/agent/skills";
  }
  // skills.mkLocalSkillFiles {
    sourceRelPath = "agents/pi/skills";
    targetDirRelPath = ".pi/agent/skills";
  }
  // shared.mkLocalFileLinks {
    sourceRelPath = "agents/pi/extensions";
    targetDirRelPath = ".pi/agent/extensions";
    extensions = [ ".js" ".ts" ];
  }
  // shared.mkLocalFileLinks {
    sourceRelPath = "agents/pi/themes";
    targetDirRelPath = ".pi/agent/themes";
    extensions = [ ".json" ];
  };
```

Re-anchor `installPiRtkHooks`, `configurePiMcpServers`, `installPiPackages`, `installPiConfig` from `entryAfter [ "installPiSkills" ]` to `entryAfter [ "linkGeneration" ]`. Shrink `fixPiPathConflicts` to an empty list → delete the entry.

- [ ] **Step 2: Cleanup, switch, verify**

```bash
rm -rf ~/.pi/agent/skills/* 
find ~/.pi/agent/extensions ~/.pi/agent/themes -maxdepth 1 -type l -delete
rtk git add mods/agents/pi.nix
rtk nix flake check
sudo darwin-rebuild switch --flake ~/.config/home-manager
ls -la ~/.pi/agent/skills ~/.pi/agent/extensions ~/.pi/agent/themes | head -40
```
Expected: community skills + pi-local skills in `~/.pi/agent/skills` (no shared-skills entries there — they come via the global store), extensions/themes as live symlinks excluding `*.test.*`. Smoke test Pi: shared skills still resolve (via `~/.agents/skills` — still populated by the old mechanism until Task 10).

- [ ] **Step 3: Commit**

```bash
rtk git add mods/agents/pi.nix
rtk git commit -m "refactor(pi): skills/extensions/themes via home.file, drop sync loops and dedupe"
```

### Task 10: Convert the global store, delete the dead machinery

**Files:**
- Create: `mods/agents/shared-store.nix`
- Modify: `mods/agents/default.nix` (import it)
- Modify: `mods/agents/skills.nix` (delete `mkAgentSkillInstall`, `mkCommunitySkillCmd`, `resetManagedDirFn`, `mkLocalSkillSyncScript`; prune exports)
- Modify: `mods/agents/claude.nix` (drop `"${home}/.agents/skills"` from `fixClaudePathConflicts` — the list then holds nothing else Claude-specific except nothing: delete the entry if empty)
- Modify: `mods/npmx.nix` (remove `"skills@latest"` from `npmxTools`)

**Interfaces:**
- Consumes: `skills.mkLocalSkillFiles` (Task 5).
- Produces: `~/.agents/skills` managed by home.file; `mods/agents/shared-store.nix` as the single owner of cross-agent store content.

- [ ] **Step 1: Create `mods/agents/shared-store.nix`**

```nix
# agents/shared-store.nix — the cross-agent global skill store (~/.agents/skills).
# Pi auto-discovers this directory directly; the other agents get the same
# shared-skills content linked into their own skill dirs by their own modules.
# One tiny module owns it so that no single agent's file has to.
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  machineRoles ? [ ],
  inputs ? { },
  ...
}:
let
  shared = import ./lib.nix { inherit config lib pkgs-unstable hostname machineRoles inputs; };
  skills = shared.callAgentLib ./skills.nix;
in
{
  home.file = skills.mkLocalSkillFiles {
    sourceRelPath = "agents/shared-skills";
    targetDirRelPath = ".agents/skills";
  };
}
```

Add `./shared-store.nix` to `mods/agents/default.nix`'s imports.

- [ ] **Step 2: Delete the dead machinery**

In `skills.nix`: remove `mkAgentSkillInstall`, `mkCommunitySkillCmd`, `resetManagedDirFn`, `mkLocalSkillSyncScript` and their exports (keep the catalog, `enabledSkillSources`, and the two/three generators). Confirm nothing references them: `rtk rg -n "mkAgentSkillInstall|mkLocalSkillSyncScript|mkCommunitySkillCmd" mods/` must return only this file pre-deletion, nothing after.

- [ ] **Step 3: Remove the now-unused `skills` CLI from npmx**

Check first: `rtk rg -n "skills (add|remove|list)" mods/ --glob '!*.md'` — if only dead references remain, remove `"skills@latest"` from `npmxTools` in `mods/npmx.nix`. (npm's global uninstall of the old copy can be manual: `npm uninstall -g skills`.)

- [ ] **Step 4: Cleanup, switch, verify**

```bash
rm -rf ~/.agents/skills/*
rtk git add mods/agents/ mods/npmx.nix
rtk nix flake check
sudo darwin-rebuild switch --flake ~/.config/home-manager
ls -la ~/.agents/skills | head -20
```
Expected: shared skills as live symlinks into `mods/dotfiles/agents/shared-skills/`. Smoke test Pi resolves a shared skill (e.g. agent-management). Revocation spot-check: temporarily remove one catalog skill from `skills.nix`, `rtk git add` + switch, confirm its symlink is gone from all four agents' dirs; restore + switch back.

- [ ] **Step 5: Commit**

```bash
rtk git add mods/agents/ mods/npmx.nix
rtk git commit -m "refactor(agents): global skill store via home.file; delete wipe-and-rebuild machinery"
```

---

## Phase 4: OpenCode consolidation

### Task 11: Merge mods/opencode.nix into mods/agents/opencode.nix

**Files:**
- Modify: `mods/agents/opencode.nix` (absorb everything from `mods/opencode.nix`)
- Delete: `mods/opencode.nix`
- Modify: whatever imports `mods/opencode.nix` (locate with the step below)

Why: "each agent owns its complete story in its own file" is currently violated for OpenCode only — its symlink layout, path-conflict fix, and agents-module concerns live in two files, which is exactly what produced the activation-name collision. `mods/opencode.nix` is already pure `home.file` + one activation entry, so this is a mechanical move.

- [ ] **Step 1: Locate the import site**

Run: `rtk rg -n "opencode" homes/ mods/default.nix mods/*.nix --glob '!mods/agents/*' -l`
Note which file imports `./opencode.nix` (or lists it in an imports array).

- [ ] **Step 2: Move the content**

Copy `mods/opencode.nix`'s `mkSym`/`mkForcedSym` helpers, its `home.file` block, and its `fixOpencodePathConflicts` activation entry into `mods/agents/opencode.nix` (merging the `home.file` attrsets with `//`). Delete `mods/opencode.nix` and remove it from the import site found in Step 1. Since there is now a single owner, the collision-era header comment about `fixOpencodeSkillPathConflicts` naming is obsolete — delete it, and keep the single entry named `fixOpencodePathConflicts`. Update the file's header comment to state it owns OpenCode's *entire* story including the live-symlinked config (`config.json` stays hand-editable by design — that's a feature, not a migration target).

- [ ] **Step 3: Verify**

```bash
rtk git add mods/
rtk nix flake check
sudo darwin-rebuild switch --flake ~/.config/home-manager
ls -la ~/.config/opencode/ | head -20
```
Expected: flake check passes (this is precisely the collision class it guards); all symlinks identical to before the move.

- [ ] **Step 4: Commit**

```bash
rtk git add mods/
rtk git commit -m "refactor(opencode): single module owns OpenCode's complete story"
```

---

## Phase 5: Full key ownership for config merges

### Task 12: Simplify JSON/TOML merges to declared-key overwrite

**Decision (confirmed with Nick):** Nix owns the entire managed key. Hand-added entries under `mcpServers`/`mcp_servers` are removed on rebuild; experiments must be promoted to Nix declarations to survive. Claude plugins and Pi packages keep tracked-state diffing (their CLIs own opaque state).

**Files:**
- Modify: `mods/dotfiles/agents/scripts/apply-managed-json-keys.js` (drop state-file logic; overwrite key)
- Modify: `mods/dotfiles/agents/scripts/apply-managed-json-keys.test.cjs` (rewrite expectations first — TDD)
- Modify: `mods/dotfiles/agents/scripts/apply-managed-toml-keys.js` + its `.test.cjs` (same)
- Modify: `mods/agents/managed-config-lib.nix` (drop `stateId` from `mkJsonManagedMerge`/`mkTomlManagedMerge`)
- Modify: `mods/agents/claude.nix`, `mods/agents/codex.nix`, `mods/agents/pi.nix` (drop `stateId` from those call sites)

**Interfaces:**
- Produces: `mkJsonManagedMerge { targetFile, managedKey, declaredEntries }` (no `stateId`); same for TOML. Script env contract shrinks to `TARGET_FILE`, `MANAGED_KEY`, `DECLARED_ENTRIES`.
- Preserved behavior: all keys in the target file *other than* `managedKey` are untouched (Claude's OAuth/history in `~/.claude.json`, Codex's model settings in `config.toml`). The TOML round-trip already loses comments today — no regression.

- [ ] **Step 1: Rewrite the JSON test to the new contract (run it, expect failure)**

Rewrite `apply-managed-json-keys.test.cjs` cases to assert: (a) declared entries land under `managedKey`; (b) an entry present under `managedKey` but not declared is REMOVED even though no state file exists; (c) sibling top-level keys are preserved byte-for-byte; (d) invalid target JSON → exit 1, file untouched; (e) missing target file → created with just the managed key; (f) no `STATE_FILE` env var is read or written.

Run: `rtk node --test mods/dotfiles/agents/scripts/apply-managed-json-keys.test.cjs`
Expected: FAIL (old script still prunes only tracked entries).

- [ ] **Step 2: Rewrite the script**

`apply-managed-json-keys.js` becomes: read `TARGET_FILE` (or `{}` if absent; exit 1 loudly on unparsable), `obj[MANAGED_KEY] = JSON.parse(DECLARED_ENTRIES)`, `atomicWriteFileSync` (keep using `lib/managed-state.js`'s `atomicWriteFileSync`; the read/write-managed-state functions lose these two callers but stay for the plugin/package scripts). Update the header comment's env contract.

Run: `rtk node --test mods/dotfiles/agents/scripts/apply-managed-json-keys.test.cjs`
Expected: PASS.

- [ ] **Step 3: Same cycle for TOML**

Rewrite `apply-managed-toml-keys.test.cjs` to the same contract (plus the existing missing-`@iarna/toml` → exit 1 case), watch it fail, rewrite `apply-managed-toml-keys.js` the same way, watch it pass:
`rtk node --test mods/dotfiles/agents/scripts/apply-managed-toml-keys.test.cjs`

- [ ] **Step 4: Update the Nix layer**

In `managed-config-lib.nix`: remove `stateId` from both merge functions' signatures and drop the `STATE_FILE=` line from both invocations (keep the `|| echo WARNING` guards and `mkStateFile` — plugins/packages still use it). Remove `stateId = ...` from the three MCP call sites in `claude.nix`, `codex.nix`, `pi.nix`.

- [ ] **Step 5: Switch, verify, clean up stale state**

```bash
rtk git add mods/
rtk nix flake check
rtk node --test mods/dotfiles/agents/scripts/
sudo darwin-rebuild switch --flake ~/.config/home-manager
python3 -c "import json;print(sorted(json.load(open('$HOME/.claude.json'))['mcpServers'].keys()))"
rm -f ~/.local/state/agents-nix/claude-mcp-servers.json ~/.local/state/agents-nix/codex-mcp-servers.json ~/.local/state/agents-nix/pi-mcp-servers.json
```
Expected: `mcpServers` contains exactly the declared set for this machine, nothing else; all script tests pass.

- [ ] **Step 6: Commit**

```bash
rtk git add mods/
rtk git commit -m "refactor(agents): config merges own the whole managed key, drop state tracking"
```

---

## Phase 6: Convergence visibility

### Task 13: Aggregate soft-fail warnings into an end-of-activation summary

**Files:**
- Create: `mods/agents/report.nix` (init + summary activation entries)
- Modify: `mods/agents/default.nix` (import it)
- Modify: `mods/agents/lib.nix` (`mkRtkHookInstall` failure lines call `_agents_warn`)
- Modify: `mods/agents/managed-config-lib.nix` (the `|| echo WARNING` guards call `_agents_warn`; the `command -v` misses in plugin/package installers too)
- Modify: `mods/npmx.nix` (the `failed > 0` block also calls `_agents_warn`)
- Modify: warning-site activation entries gain `"agentsWarnReportInit"` in their `entryAfter` lists

Why this phase runs *after* the migration: Phases 3–5 delete many of today's warning sites — instrumenting them first would be wasted work. Home-manager concatenates all DAG entries into one shell script, so a function defined in an early entry is callable from every later one; the explicit `entryAfter` additions make the ordering structural rather than accidental.

- [ ] **Step 1: Create `mods/agents/report.nix`**

```nix
# agents/report.nix — activation warning report. Soft-fail `|| warn` guards
# keep one broken mechanism from aborting the whole activation (which runs
# under set -eu), but their warnings scroll past unseen in darwin-rebuild
# output. This module collects them into one block printed at the very end,
# so "activation succeeded" and "everything actually converged" stop being
# conflatable.
{ lib, ... }:
{
  home.activation.agentsWarnReportInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export AGENTS_WARN_FILE="$HOME/.local/state/agents-nix/last-activation-warnings.txt"
    mkdir -p "$(dirname "$AGENTS_WARN_FILE")"
    : > "$AGENTS_WARN_FILE"
    _agents_warn() {
      echo "agents: WARNING: $1" >&2
      printf '%s\n' "$1" >> "$AGENTS_WARN_FILE"
    }
  '';

  # References to DAG names that don't exist on a given machine are ignored
  # by the sorter, so this list can safely name every agent's last steps.
  home.activation.agentsWarnReportSummary =
    lib.hm.dag.entryAfter
      [
        "writeClaudeInstructions"
        "writeCodexInstructions"
        "writeOpencodeInstructions"
        "writePiInstructions"
        "installPiConfig"
        "installPiPackages"
        "configureClaudeMcpServers"
        "configureCodexMcpServers"
        "configurePiMcpServers"
        "installClaudePlugins"
        "applyClaudeWorkmuxHooks"
        "applyCodexWorkmuxHooks"
        "installNpmxTools"
      ]
      ''
        if [ -s "$AGENTS_WARN_FILE" ]; then
          echo "" >&2
          echo "agents: ⚠ $(wc -l < "$AGENTS_WARN_FILE" | tr -d ' ') warning(s) this activation (also in $AGENTS_WARN_FILE):" >&2
          sed 's/^/agents:   - /' "$AGENTS_WARN_FILE" >&2
        else
          echo "agents: all managed agent assets converged cleanly"
        fi
      '';
}
```

Import from `mods/agents/default.nix`.

- [ ] **Step 2: Route existing warning sites through `_agents_warn`**

- `managed-config-lib.nix`: both merge guards become `|| _agents_warn "failed to apply managed '${managedKey}' entries to ${targetFile}"`; the `command -v claude`/`command -v pi` else-branches call `_agents_warn` instead of bare `echo >&2`.
- `lib.nix` `mkRtkHookInstall`: failure and rtk-missing branches call `_agents_warn "..."`.
- `mods/npmx.nix`: inside the `if [ "$failed" -gt 0 ]` block add `_agents_warn "npmx: $failed install step(s) failed"` (npmx runs `entryAfter [ "writeBoundary" ]` — add `"agentsWarnReportInit"` to that list).
- Every activation entry whose script now calls `_agents_warn` gains `"agentsWarnReportInit"` in its `entryAfter` list (e.g. `entryAfter [ "linkGeneration" "agentsWarnReportInit" ]`).

- [ ] **Step 3: Verify both paths**

Clean path: `rtk git add mods/ && rtk nix flake check && sudo darwin-rebuild switch --flake ~/.config/home-manager` — expect the final line `agents: all managed agent assets converged cleanly`.

Failure path: temporarily set `mcpTarget = "/tmp/agents-warn-test.json";` in `claude.nix`, run `echo 'not json' > /tmp/agents-warn-test.json`, switch, and expect the summary block reporting 1 warning. Revert the edit, switch again, confirm clean.

- [ ] **Step 4: Commit**

```bash
rtk git add mods/
rtk git commit -m "feat(agents): end-of-activation convergence report for soft-fail warnings"
```

---

## Phase 7: Documentation

### Task 14: Document the three-layer model (skill, glossary, ADR)

**Files:**
- Modify: `mods/dotfiles/agents/shared-skills/agent-management/SKILL.md`
- Modify: `CONTEXT.md` (glossary entries)
- Create: `docs/adr/0002-layered-asset-management.md`

Skill-writing practices to hold to (per skill-creator): imperative voice; explain *why* so the model can generalize, not heavy-handed MUSTs; keep the body well under 500 lines; the description frontmatter carries all "when to use" triggering.

- [ ] **Step 1: Update the skill**

Rework `SKILL.md`:

- Add a **"The three layers"** section directly after "The one rule that matters". Frame it around the sorting question — *who else writes to this path?* — since that's the decision procedure a future change needs: Layer 0 (only Nix writes it → `home.file` + flake inputs / `mkOutOfStoreSymlink`; skills, commands, Pi extensions/themes, the global store), Layer 1 (the tool also writes the file → activation-time merge that owns the whole managed key; `~/.claude.json` `mcpServers`, `~/.codex/config.toml` `mcp_servers`, `~/.pi/agent/mcp.json`), Layer 2 (the tool's installer owns opaque state → CLI driver + tracked state in `~/.local/state/agents-nix/`; Claude plugins, Pi packages, rtk). Explain why each layer's mechanism is the *strongest one available* for its constraint, so a reader doesn't "upgrade" Layer 2 to pure Nix (reimplementing installers) or "downgrade" Layer 0 to activation scripts (losing rollback/pinning).
- Rewrite **"Every mechanism must be revocable"**: Layer 0 revocation is home-manager's own link bookkeeping; Layer 1 revocation is key ownership (undeclared = removed, including hand-adds — state the behavior change explicitly); Layer 2 keeps tracked-state diffing and the existing diagnostic guidance (which now applies *only* to plugins/packages).
- Update **the file map**: add `shared-store.nix`, `report.nix`; note deleted machinery; scripts list shrinks.
- Update **Common tasks**: *Add a skill* = add a flake input (`flake = false`) + a catalog entry with `input` and per-skill `path` (verify the path via the input's store tree, not the repo README); *update skills* = `nix flake update <input-name>`; *local skills* = drop a directory under `shared-skills/` and rebuild (edits inside are live; new directories need a switch — explain the eval-time enumeration reason); *MCP servers* = same shape, plus the hand-adds-don't-survive warning; *machine gating* = `machineRoles` from flake.nix, never `MACHINE_NAME`.
- Update **Verifying**: `rtk nix flake check` is now the first-class merge-conflict check (keep the explanation of *why* attrNames-listing doesn't force merges — the lesson generalizes); keep the standalone-script-testing and git-add notes; add the end-of-activation convergence line as the thing to look for after a switch.

- [ ] **Step 2: Update CONTEXT.md and write the ADR**

`CONTEXT.md`: update the "Revocable install" entry (three per-layer revocation mechanisms; tracked-state now Layer-2-only), add glossary entries for "Layer 0/1/2" (the who-writes-it test) and "Machine roles" (flake-declared, distinct from both hostname and `MACHINE_NAME`).

`docs/adr/0002-layered-asset-management.md`: context (post-0001 weaknesses: activation-time imperative installs for immutable content, silent soft-fails, hand-add preservation machinery), decision (the three layers; pinned inputs; full key ownership; convergence report), considered options (keep wipe-and-rebuild + temp-dir hardening; `skills` CLI against store paths as permanent bridge; typed module options — rejected with reasons discussed in review), consequences (skills update via `nix flake update` instead of implicitly on rebuild; hand-added MCP entries no longer survive; rollback now covers skills).

- [ ] **Step 3: Verify and commit**

The skill file is itself a Layer 0 asset — confirm it propagates: `sudo darwin-rebuild switch --flake ~/.config/home-manager && readlink ~/.claude/skills/agent-management`, then spot-read the deployed copy. Run `rtk nix flake check` one final time.

```bash
rtk git add mods/dotfiles/agents/shared-skills/agent-management/ CONTEXT.md docs/adr/
rtk git commit -m "docs(agents): three-layer asset model in skill, glossary, and ADR 0002"
```

---

## Risks and contingencies

- **Read-only store symlinks:** if any agent writes into its skill directories (metadata, caches), its `home.file` entries switch to `recursive = true` copies (still declarative/revocable) — decide per agent at its cutover task's smoke test, not globally.
- **Private inputs need SSH at lock time only:** `nix flake update private-skills` requires an SSH agent; rebuilds use the lock and need no network for skills at all.
- **Update cadence change:** skills no longer self-update on rebuild. If that's missed in practice, a monthly `nix flake update && darwin-rebuild switch` habit (or a cron) restores it deliberately.
- **DAG summary references:** `agentsWarnReportSummary` names entries that may not all exist forever; home-manager ignores unknown DAG references, but when deleting an activation entry, grep `report.nix` for its name.
- **Mid-migration state (Tasks 6–9):** converted agents rely on `home.file`; unconverted ones still wipe/rebuild via the store-path bridge. The global store stays on the old mechanism until Task 10, so Pi's shared skills never disappear mid-sequence.
