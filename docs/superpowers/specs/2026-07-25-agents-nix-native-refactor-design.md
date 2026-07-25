# Agents Nix-Native Refactor Design

**Status:** approved for planning
**Date:** 2026-07-25
**Scope:** `mods/agents/*`, `flake.nix`, `lib/builders.nix`, `mods/opencode.nix`, `mods/npmx.nix`, `mods/dotfiles/agents/scripts/*`, `mods/dotfiles/agents/shared-skills/agent-management/`

## Purpose

The post-ADR-0001 `mods/agents/*` module is well-organized (per-agent
ownership, shared utilities without shared policy) but leans on imperative
activation scripts for work Nix could own outright, and it trades away
Nix's core guarantees invisibly: no rollback for installed assets, ~70
network fetches per rebuild for unpinned skill content, a destructive
wipe-before-fetch window, and soft-fail warnings that scroll past unseen so
"activation succeeded" and "everything converged" are conflatable. This
design moves each asset onto the strongest mechanism available for its
constraints -- without touching the per-agent module organization or any
tool's native install mechanism.

## The Sorting Question

Every managed asset is classified by one question: **who else writes to
this path?** The answer determines the layer, and each layer has exactly
one mechanism:

- **Layer 0 -- only Nix writes it.** Community skills, local
  skills/commands, Pi extensions/themes, the `~/.agents/skills` global
  store. Mechanism: `home.file`, backed by pinned flake inputs
  (`flake = false`) for fetched content and
  `config.lib.file.mkOutOfStoreSymlink` for repo-local content that should
  stay live-editable. Revocation, rollback, and conflict detection come
  from home-manager's own link bookkeeping instead of hand-rolled
  wipe-and-rebuild bash. The in-repo precedent is `mods/opencode.nix`,
  which already manages OpenCode's commands/agents/modes/themes this way.
- **Layer 1 -- Nix and the tool both write the file.** `~/.claude.json`
  (`mcpServers`), `~/.codex/config.toml` (`mcp_servers`),
  `~/.pi/agent/mcp.json`. Nix cannot own a key inside a tool-mutated file
  at build time, so an activation-time merge is structurally required --
  but it is simplified to **full ownership of the managed key**: the
  declared entry set replaces the key wholesale each activation. Hand-added
  entries under a managed key no longer survive rebuilds (they must be
  promoted to Nix declarations); in exchange, the per-key tracked-state
  files, pruning logic, corruption handling, and `legacySeed`-style
  bootstrapping all disappear for this layer.
- **Layer 2 -- the tool's own installer owns opaque state.** Claude
  plugins (`claude plugin`), Pi packages (`pi install`/`pi remove`), RTK
  hooks (`rtk init`). These keep the existing CLI-driver +
  tracked-state-diffing mechanism unchanged: reimplementing a tool's
  installer to make it "more Nix" would bypass marketplace metadata, lock
  state, and update paths -- exactly the flexibility the per-agent design
  exists to preserve.

## Layer 0 Migration Shape

Skill repos become flake inputs, so content is pinned by `flake.lock`,
fetched once into the store, and available offline; updating is a
deliberate `nix flake update <input>` instead of an implicit consequence of
rebuilding. The `agentSkillSources` catalog keeps its shape (declare once,
target N agents -- it is data, not policy) but each entry gains an `input`
and a per-skill in-repo `path`, discovered from the input's actual tree
rather than trusted from READMEs. A generator (`mkCommunitySkillFiles`)
turns the filtered catalog into `home.file` entries with `force = true`,
preserving the old wipe-and-rebuild semantics of "Nix owns this directory."

Repo-local content (shared skills, per-agent skills/commands, Pi
extensions/themes) is enumerated at eval time with `builtins.readDir` and
linked via `mkOutOfStoreSymlink`, keeping today's live-edit property: file
edits are visible immediately, only adding/removing a whole entry needs a
switch.

The migration is per-agent (Claude, Codex, OpenCode, Pi in sequence), with
the old mechanism retargeted at pinned store paths as a compatibility
bridge so unconverted agents keep working mid-sequence. The global store
converts last, once no wipe-and-rebuild caller remains, and Pi's
install-then-dedupe dance is replaced by simply not linking shared skills
into Pi's own dir (the global store covers it). The `skills` CLI npm
package is dropped once nothing invokes it.

## Safety Nets

- **Flake check** (`checks.aarch64-darwin.activation-merge-forced`):
  forces `system.activationScripts.script.text` for all darwin machines
  plus every merged `home.activation.<name>.data` value for all four
  configurations -- the exact evaluation class where the real
  `fixOpencodePathConflicts` collision hid. This automates the manual
  verification recipe the agent-management skill currently prescribes.
- **Convergence report**: soft-fail `|| warn` guards stay (one broken
  mechanism must not abort a `set -eu` activation), but warnings are
  collected into `~/.local/state/agents-nix/last-activation-warnings.txt`
  and printed as one block at the end of activation, with an explicit
  "converged cleanly" line on the happy path.
- **Machine roles**: gating booleans derive from a `roles` list declared
  per machine in `flake.nix` (threaded as a `machineRoles` specialArg)
  instead of hostname string equality, so renaming a machine cannot
  silently disable every gated asset. `MACHINE_NAME` remains a
  shell-runtime concern only.

## Consolidations

- `mods/opencode.nix` merges into `mods/agents/opencode.nix`: OpenCode is
  the only agent whose story spans two files, which is what produced the
  activation-name collision. Its live-symlinked `config.json`
  (edit-without-rebuild) is deliberately retained as-is.
- The agentmemory MCP bin path and URL move to `lib.nix` as shared
  agent-blind facts (three copies today); per-agent config shapes stay in
  each agent's file.

## Testing

- The flake check is sabotage-tested at introduction (inject a duplicate
  activation name, expect eval failure) before being trusted.
- The rewritten merge scripts keep their `node:test` suites, updated
  test-first to the new contract: undeclared entries under a managed key
  are removed even with no state file; sibling keys are untouched; invalid
  target JSON/TOML exits 1 without writing.
- Each agent's cutover ends with a switch plus link-target inspection and
  an agent smoke test; the global-store task adds a revocation spot-check
  (remove a catalog entry, confirm the link disappears everywhere).

## Non-Goals

- No typed home-manager module options layer (`options.agents.*`) -- the
  boilerplate outweighs the merge/validation benefit for a
  single-contributor repo; the flake check covers the collision risk.
- No Nixification of npm globals (`mods/npmx.nix` stays; per-package hash
  maintenance for fast-moving CLIs is toil without payoff -- ADR-0001 goal
  4 already accepted this boundary).
- No change to OpenCode's hand-edited `opencode-config.json` mechanism for
  MCP/plugins.
- No hardening of the old wipe-then-fetch installer (temp-dir + swap): the
  migration deletes the mechanism instead.
- Layer 2 mechanisms (Claude plugins, Pi packages, rtk) are untouched.

## Recommendation

Apply in seven phases: (1) flake check safety net first, (2) machine roles
+ shared-fact hoisting, (3) per-agent Layer 0 migration behind a
store-path compatibility bridge, (4) OpenCode consolidation, (5) full key
ownership for Layer 1 merges, (6) convergence report (after the migration,
so deleted warning sites aren't instrumented), (7) documentation -- the
three-layer model lands in the agent-management skill, `CONTEXT.md`
glossary, and a new ADR 0002.
