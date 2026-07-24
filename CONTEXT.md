# Context: agents/* module redesign

## Glossary

- **Revocable install** — an install mechanism where deleting a Nix declaration
  causes the previously-installed artifact to be removed on the next
  activation, with no manual bookkeeping. The reference implementation is
  `skills.nix`'s pattern: wipe every managed directory, then rebuild from the
  current declared list. Anything that only *adds/updates* declared entries
  without pruning stale ones (MCP JSON-merge, Claude plugin install) is
  **not** revocable, even though it's declarative and idempotent-in-the-add
  direction.
  For mechanisms that can't cheaply wipe-and-rebuild (MCP config merges,
  Claude plugin installs, Pi package installs), revocation instead works by
  tracking "what did I, Nix, previously manage" in a small state file under
  `~/.local/state/agents-nix/<stateId>.json` (see `managed-config-lib.nix`).
  Each run diffs the current declaration against that state, prunes anything
  previously-managed-but-now-undeclared, and never touches anything that
  never appears in that tracked state (so hand-added config or Pi packages
  installed outside of Nix are never pruned). If revocation for one of these
  mechanisms ever appears to not be working, check that directory first —
  deleting a state file resets that mechanism's prune-tracking to empty.
- **Native install mechanism** — the mechanism idiomatic to a specific agent
  for installing a capability (e.g. Claude Code's plugin marketplace, Pi's
  extensions, a raw MCP server entry, an npm/pip/brew package). A single
  capability (e.g. agentmemory) may be installed into different agents via
  different native mechanisms, and may have no supported mechanism for some
  agents at all — partial coverage across agents is expected and fine, not a
  gap to paper over with a shared abstraction.
- **Flake-declared hostname** — the `hostname` value passed to
  `mkDarwinSystem`/`mkNixOSSystem` in `flake.nix` for a given
  `darwinConfigurations`/`nixosConfigurations` entry. This is the single
  source of truth for "which machine is this" at Nix-eval time. Distinct from
  `MACHINE_NAME` (a `home.sessionVariables` string, independently hand-typed
  per `homes/home-*.nix`, consumed at *shell runtime* by bashrc functions) —
  the two must not be conflated; machine-gating booleans for agent modules
  should derive from the former, not the latter.

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
