---
name: agent-management
description: How to declaratively add, change, or remove AI coding agent assets in this Home Manager repo. Use before editing config.agents, mods/agents, agent skills, MCP servers, native plugins/packages, RTK hooks, shared instructions, or supporting reconciliation scripts.
---

# Managing agent configuration declaratively

`config.agents` is the public desired-state interface for Claude Code, Codex,
Pi, OpenCode, shared skills, instructions, providers, and global agent CLIs.
Common and role-specific profiles declare policy; per-agent adapters translate
that policy into native files and installer operations.

Read these for architectural context:

- `docs/adr/0003-declarative-agent-configuration-interface.md` — public interface
- `docs/adr/0001-per-agent-modules.md` — independent native adapters
- `docs/adr/0002-layered-asset-management.md` — ownership mechanisms

## The rule that matters

**Declarations belong above adapters.** Put common desired state in
`mods/agents/profiles/common.nix` and role-specific additions in the matching
profile such as `profiles/loancrate.nix`. Do not put machine-selection policy or
new declaration lists in `claude.nix`, `codex.nix`, `pi.nix`, or
`opencode.nix`; those files are adapters.

Adapters remain independent. Do not create a shared installer that accepts an
agent ID and branches on it. Sharing an agent-blind utility is fine; sharing
cross-agent installation policy is not.

## Public interface

The resolved configuration is under `config.agents`:

```nix
agents = {
  instructions = ".../agents/AGENTS.md";

  skills = {
    shared = [
      "tdd"
      "context7"
      { name = "brainstorming"; manualOnly = true; }
    ];
    perAgent.pi = [ ];
  };

  globalNpmTools."@playwright/cli" = "0.1.19";

  claude = {
    mcpServers = { };
    pluginMarketplaces = [ ];
    plugins = [ ];
    settings = { };
  };

  codex.mcpServers = { };
  pi = {
    mcpServers = { };
    packages = [ ];
  };
  opencode.mcpServers = { };
};
```

Inspect the fully merged value instead of reconstructing it from files:

```sh
cd pub/dotfiles-nix
nix eval --json \
  '.#darwinConfigurations.nicks-mbp.config.home-manager.users.nick.agents'
```

## Skill catalog versus skill selection

`mods/agents/skills.nix` is a pure name-to-source catalog. It says where skill
content comes from and nothing else:

```nix
{
  tdd = pinned inputs.mattpocock-skills "skills/engineering/tdd";
  agent-management = local "agents/shared-skills/agent-management";
}
```

`config.agents.skills` decides where a registered skill is installed and
whether it is manual-only. Plain strings are coerced to
`{ name = "..."; manualOnly = false; }`, so only manual-only selections need
the expanded form. `skill-files.nix` resolves and validates selections, then
emits `home.file` entries or native manual-only patches.

### Add a pinned community skill

1. Add a content-only flake input in `flake.nix` and update `flake.lock`.
2. Register its name and source in `mods/agents/skills.nix`.
3. Select the name in `profiles/common.nix`, a role profile, or
   `skills.perAgent.<agent>`.

Verify the source path against the pinned input tree:

```sh
p=$(nix eval --impure --raw --expr \
  '(builtins.getFlake (toString ./.)).inputs.some-skills.outPath')
find "$p" -name SKILL.md
```

### Add a repo-local skill

1. Add the skill directory under `mods/dotfiles/agents/shared-skills/` or an
   appropriate agent-local location.
2. Register it with `local` in `mods/agents/skills.nix`.
3. Select it through `config.agents.skills`.

Local content remains an out-of-store symlink, so edits are live. Adding the
catalog entry or directory still requires `git add` before flake evaluation.

### Make a skill manual-only

Expand that skill's selection and colocate the policy:

```nix
{ name = "brainstorming"; manualOnly = true; }
```

The adapters realize that intent natively:

- Claude: `settings.json` `skillOverrides`
- Pi: `disable-model-invocation: true` in a patched `SKILL.md`
- Codex: `agents/openai.yaml` with implicit invocation disabled
- OpenCode: unsupported upstream; do not assume the declaration is enforceable

## Native agent declarations

Keep native shapes under the corresponding agent in a profile. Duplication
between agents is acceptable when their formats genuinely differ.

### Add an MCP server

Add it to `agents.<agent>.mcpServers`. For a work-only server, put it in
`profiles/loancrate.nix`; do not add `condition = isLoancrateMac` inside an
adapter.

Claude/Pi adapters own their JSON key wholesale, Codex owns its TOML key
wholesale, and OpenCode merges the desired map into its generated config.
Hand-added entries under those managed keys do not survive activation.

### Add a Claude plugin

Declare marketplace sources in `agents.claude.pluginMarketplaces` and plugin
specs in `agents.claude.plugins`. The Claude adapter handles registration,
managed-only pruning, and state tracking.

### Add a Pi package

Declare its native source spec in `agents.pi.packages`. The Pi adapter prunes
only package specs previously installed by this mechanism.

### Add a global npm agent CLI

Declare an exact version:

```nix
agents.globalNpmTools."@scope/package" = "1.2.3";
```

Mutable tags and ranges are not valid desired state. Update the declared version
explicitly when refreshing upstream.

## Ownership layers

Adapters choose the mechanism based on who else writes the target:

- **Layer 0 — only Nix writes it:** `home.file`; used for skill links and other
  declarative files. Home Manager provides revocation and rollback.
- **Layer 1 — Nix and the tool write one config file:** activation-time managed
  key replacement. Sibling keys survive; hand-added values under the managed
  key do not.
- **Layer 2 — a native installer owns opaque state:** CLI reconciler plus
  tracked ownership. It must prune only previously managed assets, record
  success only after validation, repair unhealthy state, and skip expensive
  work when healthy and unchanged.

These layers are adapter internals, not fields in `config.agents`.

## Revocation

Deleting desired state must remove only the corresponding managed asset:

- Skill link: Home Manager removes it.
- MCP/config entry: the adapter rewrites its managed key without it.
- Plugin/package: tracked ownership tells the reconciler what it may uninstall.

Never prune all native inventory merely because it is absent from Nix; that
would remove manually installed assets.

## Convergence, repair, and update

A normal switch converges declared state and must not query registries or invoke
installers when local inventory is healthy and unchanged. Freshness is an
explicit operation, not part of convergence.

```sh
# Reinstall/repair the currently declared assets.
AGENTS_FORCE_REPAIR=1 darwin-rebuild switch --flake .

# Refresh mutable Claude/Pi native assets explicitly.
AGENTS_UPDATE=1 darwin-rebuild switch --flake .
```

Run `agents-check-updates` for an explicit registry check of exact global npm
tool versions. Update the reported `agents.globalNpmTools` declarations; the
next switch installs only changed versions. Skills remain pinned by
`flake.lock` and update through `nix flake update <input>`.

## Verification

Run from the dotfiles flake, not the monorepo root:

```sh
cd pub/dotfiles-nix
nix flake check
system=$(nix eval --impure --raw --expr builtins.currentSystem)
nix build ".#checks.${system}.agent-config-resolved" --no-link
```

The first check forces merged activation values. The second serializes the
public desired state for every managed host.

For adapter scripts, run the adjacent Node test directly:

```sh
node --test mods/dotfiles/agents/scripts/<adapter>.test.cjs
```

New files must be staged before Nix flakes can see them. After activation, read
the aggregated agent convergence report; a successful Home Manager switch does
not by itself prove every soft-failing native installer converged.
