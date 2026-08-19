---
name: agent-management
description: How to declaratively add, change, or remove AI coding agent assets — skills, MCP servers, plugin/capability installs, RTK hooks, shared instructions — in this home-manager repo's mods/agents/*.nix module. Use this whenever the user asks to add a skill, add an MCP server, install a plugin for Claude/Codex/OpenCode/Pi, gate something to a specific machine, update a pinned skill, or asks why removing something from mods/agents/*.nix didn't actually remove it after a rebuild. Also use this before writing any new code under mods/agents/ or mods/dotfiles/agents/scripts/, even if the user doesn't name this skill directly — this architecture has specific, non-obvious rules (see "The one rule that matters" and "The three layers") that are easy to violate by copying an old pattern.
---

# Managing agent assets declaratively

This repo installs the same kinds of things — skills, MCP servers, plugins, RTK hooks, shared instructions — into four AI coding agents (Claude Code, Codex, OpenCode, Pi) via `mods/agents/*.nix`. The architecture is deliberate and documented in full at `docs/adr/0001-per-agent-modules.md` (per-agent ownership) and `docs/adr/0002-layered-asset-management.md` (the layer model), with vocabulary in `CONTEXT.md`. Read those for the "why"; this skill is the "how".

## The one rule that matters

**Each agent owns its complete installation story in its own file** (`mods/agents/claude.nix`, `codex.nix`, `opencode.nix`, `pi.nix`). There is no shared script that takes an `agents = [...]` list and branches on agent identity internally. That pattern used to exist here, caused real bugs, and was deliberately torn out — see ADR 0001.

The dividing line: a **shared utility** that takes a file path, an agent ID string, or other caller-supplied identity — and does not know or care which agent is calling it — is fine to share (`lib.nix`, `skills.nix`, `instructions.nix`, `managed-config-lib.nix` are all built this way). A **shared script that owns a cross-agent declared list and switches behavior per agent** (`if agent == "codex" then ... else ...`) is the anti-pattern. If you catch yourself writing that second shape, stop and put the logic in the one agent file that needs it.

## The three layers

Every managed asset is sorted by one question: **who else writes to this path?** The answer picks the mechanism, and each layer has exactly one. Getting the layer right is the difference between a clean revocable install and a subtle drift bug.

- **Layer 0 — only Nix writes it.** Community skills, local skills/commands, Pi extensions/themes, the `~/.agents/skills` global store. Mechanism: **`home.file`**, backed by pinned flake inputs (`flake = false`) for fetched content and `config.lib.file.mkOutOfStoreSymlink` for repo-local content that stays live-editable. Revocation, rollback, and conflict detection all come from home-manager's own link bookkeeping — no activation script. Don't "upgrade" this to an activation script: you'd lose rollback and pinning.
- **Layer 1 — Nix and the tool both write the file.** `~/.claude.json` (`mcpServers`), `~/.codex/config.toml` (`mcp_servers`), `~/.pi/agent/mcp.json`. Nix can't own a key inside a tool-mutated file at build time, so an activation-time merge is required — but it owns the managed key **wholesale**: the declared set replaces that key every run. **Hand-added entries under a managed key do not survive a rebuild** (that's the deliberate trade for having no state files here — promote experiments to Nix). Sibling keys the tool writes (Claude's OAuth/history, Codex's settings) are preserved.
- **Layer 2 — the tool's own installer owns opaque state.** Claude plugins (`claude plugin`), Pi packages (`pi install`/`pi remove`), RTK hooks (`rtk init`). These keep a CLI-driver + tracked-state file in `~/.local/state/agents-nix/<stateId>.json`: each run diffs the declaration against what Nix previously installed and prunes only that, never touching things installed outside Nix. Don't "upgrade" this to pure Nix — you'd be reimplementing the tool's installer and lose its marketplace/lock/update behavior.

## The file map

| File | Owns |
|---|---|
| `mods/agents/lib.nix` | Agent-blind facts and utilities: `dotfiles`, `home`, `allAgents`, machine roles (`isLoancrateMac`), shared agentmemory facts, `mkFixPathConflicts`, `mkRtkHookInstall`, `mkWarn`, `mkLocalFileLinks`, `mkDeclaredEntriesFromSources`, `callAgentLib` |
| `mods/agents/skills.nix` | The cross-agent skill **catalog** (one declared list — see below) + the `home.file` generators `mkCommunitySkillFiles`/`mkLocalSkillFiles`, plus `mkSkillOverrides`/`mkPatchedSkillSource` for manual-only skills (see below) |
| `mods/agents/shared-store.nix` | The cross-agent global store `~/.agents/skills` (Pi auto-discovers it), via `home.file` |
| `mods/agents/instructions.nix` | The shared `AGENTS.md` source + `writeAgentInstructions`/`removeStaleInstructionSymlink` |
| `mods/agents/managed-config-lib.nix` | Layer 1 JSON/TOML full-key merge (`mkJsonManagedMerge`, `mkTomlManagedMerge`) and Layer 2 CLI diff+prune (`mkClaudePluginInstall`, `mkPiPackageInstall`) |
| `mods/agents/report.nix` | The end-of-activation convergence report (aggregates `mkWarn` output) |
| `mods/agents/{claude,codex,opencode,pi}.nix` | Each agent's **entire** story: its `home.file` skill links, its own MCP declarations, its own native plugin/package installs, RTK hook, instruction write |
| `mods/agents/default.nix` | Imports the four per-agent files + `shared-store.nix` + `report.nix` |
| `mods/dotfiles/agents/scripts/*.js` | The Node scripts the Layer 1/2 utilities shell out to (JSON/TOML full-key write, Claude plugin diff, Pi package diff) |
| `mods/dotfiles/agents/scripts/lib/managed-state.js` | The shared atomic-write + "previously-managed name set" logic the Layer 2 diff scripts use |

### Why the skill catalog is still one file

`agentSkillSources` in `skills.nix` is a single list where each entry declares a skill once (a flake `input` + per-skill `{ name; path; }`) and targets N agents via an `agents = [...]` field. This looks like the anti-pattern above but isn't: it's **data**, not a script that branches on agent identity. The generators (`mkCommunitySkillFiles`) filter this list by `agentId` and return a `home.file` attrset scoped to one agent's dir — each agent module calls it itself. Don't split the catalog into four copies. Do keep capability installs (MCP servers, plugins, packages) out of a similar shared list — those genuinely differ per agent's native mechanism.

## Every mechanism must be revocable

Deleting a declaration must make the thing disappear on the next `darwin-rebuild switch`, no manual cleanup. Each layer achieves this differently:

- **Layer 0**: home-manager's own link bookkeeping. Drop a catalog entry or a `shared-skills/<name>/` dir → the symlink is gone next switch. This is the strongest form (rollback works too).
- **Layer 1**: full key ownership. The managed key is rewritten from the declaration each run, so a removed entry is simply absent next time. No state file involved.
- **Layer 2**: tracked-state diffing. Removing a declaration prunes it because the state file recorded that Nix installed it.

**If a user says "I removed X but it's still there after rebuilding"**, work the layers:
1. Is it a skill (Layer 0)? Then either the removal isn't `git add`ed (flakes only see tracked files — an unstaged edit is invisible to the build), or the entry is still declared. Check the actual catalog/dir.
2. Is it an MCP server (Layer 1)? Under full ownership it can only persist if it's still declared in that agent's `mcpSources`, or was hand-added under the key (which now gets wiped on rebuild anyway). Confirm it's actually removed from the `.nix` file and `git add`ed.
3. Is it a plugin/package (Layer 2)? Check `~/.local/state/agents-nix/<stateId>.json`. If it's missing or never recorded the entry (the thing predates tracking), it won't prune — see "Migrating something that predates tracking".

## Common tasks

### Add a community skill

Two steps, because skills are Layer 0 pinned content:

1. Add a flake input in `flake.nix` (content repo, not a flake):
   ```nix
   some-skills = { url = "github:owner/repo"; flake = false; };
   ```
   For a private repo use `url = "git+ssh://git@github.com/owner/repo";`. Run `nix flake lock` (SSH creds needed for private).
2. Add a catalog entry in `skills.nix`:
   ```nix
   {
     input = inputs.some-skills;
     skills = [ { name = "the-skill"; path = "skills/the-skill"; } ];
     agents = allAgents;  # or a subset like [ "claude-code" "pi" ]
   }
   ```
   **Verify `path` against the input's actual store tree, not the README** — directory names drift (this repo already hit `diagnose` → `diagnosing-bugs`). Find it with:
   ```sh
   p=$(nix eval --impure --raw --expr "(builtins.getFlake (toString ./.)).inputs.some-skills.outPath")
   find "$p" -name SKILL.md | sed "s|$p/||"
   ```
   A skill whose `SKILL.md` is at the repo root uses `path = "."`.

For a skill that lives in **this repo** (not fetched), drop a `SKILL.md` under `mods/dotfiles/agents/shared-skills/<name>/` — no catalog entry needed; `shared-store.nix` and each agent's `mkLocalSkillFiles` call link it everywhere automatically, and edits to it are live (out-of-store symlink).

### Make a skill manual-only (invisible to progressive disclosure)

For a skill you only want invoked by explicit name — never auto-triggered by Claude/Pi/Codex matching its description — add `disableModelInvocation = true;` to its entry in `skills.nix`'s catalog:
```nix
{ name = "the-skill"; path = "skills/the-skill"; disableModelInvocation = true; }
```
This is a plain intent flag on the skill — it says nothing about which agents can honor it. `manualOnlyCapableAgents` (in `skills.nix`) separately declares which agents actually have a manual-only mechanism today, and `isSkillManualOnlyFor { s; agentId; }` combines the two. Keeping "the skill wants this" and "the agent can do this" as two separate declarations means a skill's flag never needs editing when an agent gains or loses support — only `manualOnlyCapableAgents` changes.

Each capable agent realizes "manual-only" its own way (no shared mechanism, per "the one rule that matters") by calling `isSkillManualOnlyFor` for its own `agentId`:
- **Claude Code**: `mkSkillOverrides { agentId = "claude-code"; }` collects matching skills into `{ skillName = "user-invocable-only"; }`, applied to `~/.claude/settings.json`'s `skillOverrides` key via `mkJsonManagedMerge` (Layer 1 — revocable the same way `mcpServers` is).
- **Pi**: honors `disable-model-invocation: true` natively in a skill's own `SKILL.md` frontmatter, but catalog skills are read-only pinned store paths — `pi.nix`'s `patchPiSkillSource` uses `mkPatchedSkillSource` to splice that key into a patched copy instead of the vendored file.
- **Codex**: its real control is a sibling `agents/openai.yaml` (`policy.allow_implicit_invocation: false`), not the frontmatter field — `codex.nix`'s `patchCodexSkillSource` injects that file into a patched copy via `mkPatchedSkillSource`.
- **OpenCode**: not in `manualOnlyCapableAgents` — no mechanism exists upstream (anomalyco/opencode#11972 is open, unresolved). Add it there once that lands; no catalog skill needs touching.

`mkPatchedSkillSource` is the shared Layer 0 primitive behind Pi/Codex: it copies a skill's store path into a new derivation and either adds files or splices a line into an existing one (generic patch specs, not agent identity — see its doc comment in `skills.nix`). It's revocable the same way any Layer 0 asset is: drop `disableModelInvocation`, the unpatched symlink comes back next switch.

For a **local skill** (not in the catalog — see "Add a community skill" above), skip all of this: just hand-edit that skill's own `SKILL.md`/`agents/openai.yaml` directly, since those files are already live-editable out-of-store symlinks.

### Update a pinned skill

`nix flake update <input-name>` then rebuild. Skills no longer auto-update on every rebuild — that's deliberate (pinned = reproducible/auditable). A periodic `nix flake update` is how you pull upstream changes.

### Add an MCP server

Each agent that needs it gets its own entry in its own file — there's no shared MCP list. Add to that agent's `mcpSources`:
```nix
{
  name = "my-server";
  condition = someBoolOrOmit;   # optional, defaults to true
  config = { command = "/path/to/bin"; env = { X = "y"; }; };
}
```
It flows through `shared.mkDeclaredEntriesFromSources` into the agent's existing `mkJsonManagedMerge` (Claude/Pi) or `mkTomlManagedMerge` (Codex) call — no new wiring. If the server needs a different shape per agent, declare it separately in each; don't unify the shapes. **Note the Layer 1 trade**: this key is fully owned, so a server someone adds by hand with `claude mcp add` will be wiped on the next rebuild unless it's declared here.

OpenCode is the exception: its generated config starts from `mods/dotfiles/opencode-config.json` instead of using an activation-time managed-key merge. Add MCP servers needed on every machine to that JSON base. Add machine-role-specific servers as a conditional overlay in `mods/agents/opencode.nix`, merging them into `baseOpencodeConfig.mcp` while preserving the base entries.

### Add a Claude plugin (Layer 2)

Add the spec (`"<plugin>@<marketplace>"`) to `declaredPlugins` in `claude.nix` and make sure `pluginMarketplace` points at its marketplace (one marketplace per activation). Gate with `lib.optionals someCondition [...]` like the existing Loancrate plugins.

### Add a native capability for one agent only

Partial coverage is expected, not a gap. Use what's idiomatic to that agent: Pi packages → `declaredPiPackages` in `pi.nix`; Pi extensions → a file under `mods/dotfiles/agents/pi/extensions/`; OpenCode plugins → `opencode-config.json`'s `"plugin"` array. Don't invent a shared "capability" list.

### Gate something to a specific machine

Use `shared.isLoancrateMac`, or add a new boolean to `lib.nix` derived from **`machineRoles`** (the roles list declared per machine in `flake.nix` and threaded as a specialArg) — e.g. `isPersonalMac = builtins.elem "personal" machineRoles;`. Never gate on `MACHINE_NAME` (a hand-typed `home.sessionVariables` string used only by bashrc at shell runtime — see `CONTEXT.md`). Roles beat hostname strings because renaming a machine can't silently disable a gate.

### Migrating something that predates tracking (Layer 2 only)

Moving an old imperative removal onto a tracked-state mechanism? Seed the state file once so enforcement doesn't silently stop. `mkPiPackageInstall`'s `legacySeed` is the reference: it seeds previously-known-stale specs only if the state file doesn't exist yet, so the first run under the new mechanism still prunes them.

## Verifying a change actually works

- **`rtk nix flake check` is the first-class check — run it from `pub/dotfiles-nix/`, not the monorepo root.** This directory is its own flake; the monorepo root has a different flake with its own (unrelated) `checks` output. Running from the root silently checks the wrong thing — e.g. its `devShells` check — and reports success without evaluating any agents/*.nix change at all. `cd pub/dotfiles-nix` first. From there, `rtk nix flake check` builds `checks.aarch64-darwin.activation-merge-forced`, which forces `system.activationScripts.script.text` and every `home.activation.<name>.data` for all machines — the exact evaluation `darwin-rebuild switch` does. This catches option-merge conflicts (two files defining `home.activation.<sameName>`), which are invisible to `nix-instantiate --parse` and to `nix eval ...--apply builtins.attrNames` (listing keys does **not** force their merged values). A real collision here — `mods/opencode.nix` vs `mods/agents/opencode.nix` both defining `fixOpencodePathConflicts` — is exactly what this guards.
- **`git add` matters.** Flakes only see tracked (or staged) files, so a brand-new file or an edit is invisible to `nix eval`/`nix build`/`flake check` until at least `git add`ed. Staging is enough.
- **Test scripts standalone.** Anything under `mods/dotfiles/agents/scripts/` is plain Node with a documented env-var contract (see each script's header) and a `.test.cjs` suite — run `node --test <file>` against scratch dirs before trusting the Nix wiring.
- **After a switch, read the convergence line.** `report.nix` prints either `agents: all managed agent assets converged cleanly` or an aggregated `⚠ N warning(s)` block (also saved to `~/.local/state/agents-nix/last-activation-warnings.txt`). "Switch succeeded" and "everything converged" are not the same thing — the soft-fail guards keep one broken mechanism from aborting activation, so check this line.
