# Context: agents/* module redesign

## Glossary

- **Revocable install** — an install mechanism where deleting a Nix declaration
  causes the previously-installed artifact to be removed on the next
  activation, with no manual bookkeeping. Which mechanism provides revocation
  depends on the asset's **layer** (see below); all three layers meet the bar.
  If revocation appears not to work, identify the layer first — a Layer 0 miss
  is almost always an un-`git add`ed edit (flakes don't see untracked files);
  a Layer 2 miss is a missing/stale `~/.local/state/agents-nix/<stateId>.json`.
- **Layer 0 / Layer 1 / Layer 2** — assets are sorted by *who else writes the
  target path*, and each layer has one mechanism (see
  `docs/adr/0002-layered-asset-management.md`):
  - **Layer 0 (only Nix writes it)** — skills, commands, Pi extensions/themes,
    the `~/.agents/skills` store. Mechanism: `home.file` (pinned flake inputs
    for fetched content; `mkOutOfStoreSymlink` for live-editable repo content).
    Revocation is home-manager's own link bookkeeping; rollback works.
  - **Layer 1 (Nix + the tool both write the file)** — `~/.claude.json`
    `mcpServers`, `~/.codex/config.toml` `mcp_servers`, `~/.pi/agent/mcp.json`.
    Mechanism: activation-time **full key ownership** — the declared set
    replaces the managed key each run; sibling keys are preserved; hand-added
    entries under the key do not survive. No state file.
  - **Layer 2 (the tool's installer owns opaque state)** — Claude plugins, Pi
    packages, RTK hooks. Mechanism: CLI driver + tracked-state diff in
    `~/.local/state/agents-nix/<stateId>.json`; prunes only what Nix previously
    installed, never touching out-of-Nix installs.
- **Native install mechanism** — the mechanism idiomatic to a specific agent
  for installing a capability (e.g. Claude Code's plugin marketplace, Pi's
  extensions, a raw MCP server entry, an npm/pip/brew package). A single
  capability (e.g. agentmemory) may be installed into different agents via
  different native mechanisms, and may have no supported mechanism for some
  agents at all — partial coverage across agents is expected and fine, not a
  gap to paper over with a shared abstraction.
- **Machine roles** — a `roles` list (e.g. `[ "work" "loancrate" ]`) declared
  per machine in `flake.nix` and threaded as the `machineRoles` specialArg
  (via `lib/builders.nix`). The source of truth for machine-gating agent
  assets: booleans like `isLoancrateMac` derive from it (`builtins.elem
  "loancrate" machineRoles`). Preferred over gating on the flake-declared
  hostname string because renaming a machine can't silently disable a gate.
- **Native install mechanism** — the mechanism idiomatic to a specific agent
  for installing a capability (e.g. Claude Code's plugin marketplace, Pi's
  extensions, a raw MCP server entry, an npm/pip/brew package). A single
  capability (e.g. agentmemory) may be installed into different agents via
  different native mechanisms, and may have no supported mechanism for some
  agents at all — partial coverage across agents is expected and fine, not a
  gap to paper over with a shared abstraction.
- **Flake-declared hostname** — the `hostname` value passed to
  `mkDarwinSystem`/`mkNixOSSystem` in `flake.nix` for a given
  `darwinConfigurations`/`nixosConfigurations` entry, the eval-time identity of
  a machine. Distinct from `MACHINE_NAME` (a `home.sessionVariables` string,
  independently hand-typed per `homes/home-*.nix`, consumed at *shell runtime*
  by bashrc functions) — the two must not be conflated. Machine-gating booleans
  for agent modules derive from **machine roles** (above), not from the
  hostname string directly and never from `MACHINE_NAME`.
- **Model-runtime backend** — the one local LLM runtime a machine uses
  (`ollama` on Intel Macs, `mlx-lm` on Apple Silicon). Selected by the
  `modelRuntimes.backend` option in `mods/model-runtimes.nix`, defaulting by
  platform (`aarch64-darwin → mlx-lm`, else `ollama`) and overridable per host.
  That module manages the runtime's **model set** declaratively — a Layer 2
  tracked-state mechanism (the same shape as the agents' Pi-package installer:
  pull declared, prune only previously-managed models, leave hand-pulled ones)
  driven by a backend-agnostic engine (`apply-models.js`) plus per-backend
  command adapters. It manages models only, not the runtime install (that's the
  brew/cask in `darwin-base.nix`). It lives outside `mods/agents/` — a sibling
  domain reusing the pattern, not part of it. See
  `docs/superpowers/specs/2026-07-27-declarative-model-runtimes-design.md`.

## Decisions

- **Revocation bar**: all four install mechanisms in the agents/* redesign
  (skills, MCP servers, plugin installs, arbitrary package installs) must
  reach the same revocable standard as `skills.nix` already has. The current
  behavior of `apply-mcp-servers.js` (add/update only, never prune) and
  `plugins.nix` (install only, no removal at all) are confirmed defects to
  fix, not acceptable trade-offs.
- **No cross-agent capability abstraction**: there is no shared "install this
  plugin/capability for agent X" function that branches per agent internally.
  Each agent gets its own module; each module declares, in its own terms,
  which capabilities it installs and via which native mechanism. A capability
  is not a first-class shared entity — it's just whatever repeated name a
  human uses when eyeballing "agentmemory is declared in claude.nix's plugin
  list and also in pi.nix's extension list."
- **Machine gating must derive from the flake's own hostname**, not a
  separately hand-maintained string. `hostname` is currently accepted but
  silently discarded by both builder functions in `lib/builders.nix` — this
  is a bug to fix as part of (or before) the redesign, independent of
  `MACHINE_NAME`'s continued existence for shell-runtime purposes.
- **Shared facts vs. shared behavior across agent modules** (goal 5),
  resolved: a **shared utility** (parameterized by file format or by
  explicit caller-supplied identity like `agentId`/`skillDir`, with no
  internal branching on "which agent is this") is fine to share. A **shared
  policy** (one script that owns a cross-agent declared list and branches
  `if agent == X then ... else ...` internally) is not — that's the coupling
  being eliminated. Concretely:
  - `skills.nix` keeps the cross-agent catalog (`agentSkillSources`, still
    declare a skill once and target N agents — this is DRY data, not
    branching behavior) but stops owning `home.activation.installAgentSkills`.
    It instead exposes a function (e.g. `mkAgentSkillInstall { agentId,
    skillDir }`) that filters the catalog and returns a bash script scoped to
    one agent's directory. Each agent module calls this itself and owns the
    resulting `home.activation.install<Agent>Skills` entry — its own timing,
    its own ordering relative to that agent's other steps.
  - MCP-server writing, plugin/capability installs, and **RTK hook
    installation** (previously `hooks.nix`, explicitly confirmed to also
    split — no cross-cutting dev-tool-integration file, RTK is a per-agent
    concern like everything else) all move into each agent's own module.
    Format-specific write utilities (JSON-merge-with-prune, TOML-merge-with-
    prune) may still be shared functions, called with each agent's own file
    path + declared set — never a shared script holding a cross-agent list.
  - Net result: `mods/agents/{claude,codex,opencode,pi}.nix` each own their
    complete installation story end to end. `lib.nix` shrinks to genuinely
    agent-blind facts (hostname-derived machine booleans, repo paths).
    `skills.nix` shrinks to catalog + utility function, no activation.

- **`instructions.nix`'s shared AGENTS.md propagation**, resolved: the call
  site moves into each agent module too, same as skills/MCP/plugins/RTK.
  `instructions.nix` shrinks to just the shared source file + a
  `writeAgentInstructions { target }` utility function (agent-blind, same
  "shared utility not shared policy" shape as everything else). Each agent
  module calls it for its own instruction path, and — for Codex specifically
  — chains its own RTK-reference-reapply step immediately after, in the same
  file, replacing today's cross-file `reapplyCodexRtkReference` hack.

## Open questions

(none outstanding — see `docs/adr/0001-per-agent-modules.md` for the settled
architecture)
