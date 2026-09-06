---
name: agent-management
description: How to declaratively add, change, or remove AI coding agent assets in this Home Manager repo. Use before editing config.agents, mods/agents, mods/internal tooling, agent skills, MCP servers, native plugins/packages, RTK hooks, shared instructions, or supporting reconciliation scripts.
---

# Managing agent configuration declaratively

`config.agents` is the public desired-state interface for Claude Code, Codex,
Pi, OpenCode, shared skills, instructions and providers. Shared choices live in
public `mods/` modules; host overrides live in `homes/`. Private adapters under
`mods/internal/` translate that policy into native files and installer operations.
npm/uv selections are separate, under `nativeTools.*` in `mods/native-tools.nix`.

Read these for architectural context:

- `docs/adr/0003-declarative-agent-configuration-interface.md` — public interface
- `docs/adr/0001-per-agent-modules.md` — independent native adapters
- `docs/adr/0002-layered-asset-management.md` — ownership mechanisms

## The rule that matters

**Declarations belong above adapters.** Put common desired state in
`mods/agents/default.nix`; make host-specific additions in `homes/home-*.nix`
or a configuration file explicitly imported there, such as
`homes/nicks-loancrate-mbp/agents.nix`. Do not put selections in
`mods/internal/agents/{claude,codex,pi,opencode}.nix`; those files are adapters.

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
3. Select the name in `mods/agents/default.nix` or a host configuration, using
   `skills.shared` or `skills.perAgent.<agent>`.

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
`homes/nicks-loancrate-mbp/agents.nix`; do not add `condition = isLoancrateMac` inside an
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

### Add a global npm tool (including agent CLIs)

npm and uv are peer domains, not agent configuration. Select an exact version
in `mods/native-tools.nix`:

```nix
nativeTools.npm.tools."@scope/package" = "1.2.3";
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
would remove manually installed assets. Do not add a second list of removed
packages: deleting the declaration is sufficient for previously tracked assets.
Missing state starts with no ownership; legacy state formats retain their
recorded ownership, but hard-coded migration seeds are not used.

## Convergence, repair, and update

A normal switch converges declared state and must not query registries or invoke
installers when local inventory is healthy and unchanged. Freshness is an
explicit operation, not part of convergence.

Claude/Pi/npm/uv share `scripts/lib/reconcile-installs.js`, which records success and
retry state per asset. Adapters provide native local health probes; inspection
uncertainty is not automatically treated as a missing installation. Keep
activation code generation-bound through `mods/internal/native-scripts.nix`; referencing
`homeManagerRelPath` for these installers can silently run stale code from a
different checkout. Shared instructions and RTK resources are now Home Manager
files; instruction edits need a rebuild. Local skills/extensions and editable
Python sources stay live; Python dependency metadata changes trigger reinstall.
TOML dependencies are Nix-packaged, never bootstrapped into the mutable checkout.

Adapters register commands in the internal `globalToolOperations` option.
`mods/internal/global-tools.nix` derives activation entries and the CLI from one validated
named-dependency plan (`after` orders operations; it does not gate on success).
Keep independent files in separate operations and project same-file edits before
writing once. Register `nativeManagedFiles` from the exact `home.file` keys an
adapter creates, never by scanning a global path prefix. Keep commands
strict (nonzero on failure); only activation's dispatcher soft-fails them.

```sh
global-tools status                # read-only native/config/link checks
global-tools repair                # native repair + writable config convergence
global-tools repair pi-packages    # one component
global-tools check-updates         # exact npm freshness only
global-tools update                # mutable Claude/Pi refresh only
```

These use the installed generation's declarations, not an arbitrary checkout.
`global-tools repair` reports broken Home Manager links but does not recreate them;
restore Nix-owned files with a switch. `global-tools-check-updates` is the standalone shortcut.
RTK is selected with `agents.<agent>.rtk.enable` and generated from
`agents.rtkPackage` in isolated Nix builds. Never reintroduce live `rtk init`
activation against the now-immutable instruction files.

Native npm/uv declarations live separately under `nativeTools.npm` and
`nativeTools.uv`, selected in `mods/native-tools.nix`. Their scripts and
tests live under `mods/internal/{npm,uv}/scripts/`; neither depends on agent enablement. Vocal is a Nix Python runtime, not a uv tool.
Retain the removal-only legacy Vocal path and old-state readers until all hosts
have migrated and the supported rollback window has closed; do not seed ownership
from untracked inventory. Follow `docs/contracts/global-tools-migrations.md` for
per-host read-only MCP audits and RTK reproducibility checks on upgrades.

```sh
# Reinstall/repair the currently declared assets.
GLOBAL_TOOLS_FORCE_REPAIR=1 darwin-rebuild switch --flake .

# Refresh mutable Claude/Pi native assets explicitly.
GLOBAL_TOOLS_UPDATE=1 darwin-rebuild switch --flake .
```

Run `global-tools check-updates` for an explicit registry check of exact global npm
tool versions. Update the reported `nativeTools.npm.tools` declarations; the
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

`nix flake check` forces merged activation values, serializes desired state,
and runs `native-install-contract`: subprocess fixtures against the actual
immutable script bundle plus generation-binding assertions for every host.
The checks are exposed equally on all managed systems. `global-tools-config` runs
actual config commands with only their HOME paths redirected into a sandbox;
`rtk-runtime` and `vocal-runtime` build and check the Nix-owned resources.
Foreign-platform checks can be evaluated with `nix flake check --all-systems
--no-build`; runtime execution still requires a builder for that platform.

For adapter scripts, run the adjacent Node test directly:

```sh
node --test mods/internal/agents/scripts/<adapter>.test.cjs
```

New files must be staged before Nix flakes can see them. After activation, read
the aggregated agent convergence report; a successful Home Manager switch does
not by itself prove every soft-failing native installer converged.
