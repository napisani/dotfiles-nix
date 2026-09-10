# Declarative tooling: architecture and operations

The agent configuration architecture is defined by:

- [ADR 0003](../adr/0003-declarative-agent-configuration-interface.md): typed
  desired state and profile composition
- [ADR 0001](../adr/0001-per-agent-modules.md): independent native adapters
- [ADR 0002](../adr/0002-layered-asset-management.md): ownership and
  revocation mechanisms

## Public desired state

`config.agents` is the interface for reviewing and changing a host's agent
configuration. It contains:

- enabled agents and their native MCP/settings declarations;
- selected shared and per-agent skill names plus manual-only policy;
- shared instruction source and per-agent `rtk.enable` selections;
- shared provider endpoints/models;
- Claude marketplaces/plugins and Pi packages.

Shared agent choices live in `mods/agents/default.nix`. Host differences are
explicit in `homes/home-*.nix`; the Loancrate host imports
`homes/nicks-loancrate-mbp/agents.nix`. Native-tool choices live in
`mods/native-tools.nix`, with npm registry policy declared by the host.
Implementation modules never select host profiles. `homes/profiles/` only
composes shared/platform modules.

The fully merged value is inspectable with `nix eval`. Each managed system
exports `checks.<system>.agent-config-resolved`, which serializes every host's
configuration so evaluation coverage is symmetric across architectures. The
separate `native-tools-resolved` check serializes npm/uv declarations for all
hosts; npm tools are not hidden in an agent-config artifact.

## Catalogs, profiles, and adapters

- `mods/agents/skills.nix` is a pure skill name-to-source catalog. It contains
  no machine, agent-selection, or manual-only policy.
- `mods/internal/agents/skill-files.nix` validates selected names, resolves catalog
  sources, and provides agent-blind rendering/patching utilities.
- Public `mods/` modules own shared choices; `homes/` owns host overrides.
  `mods/internal/` contains implementation modules and their scripts/tests.
- `mods/internal/agents/{claude,codex,pi,opencode}.nix` are independent adapters. Each
  translates only its portion of `config.agents` into native state.
- `nativeTools.npm` and `nativeTools.uv` are peer domains alongside agent
  configuration. `mods/native-tools.nix` selects shared tools; the host selects
  registry policy. `mods/internal/npm.nix` and `mods/internal/uv.nix` own realization.
  Disabling agents does not change either domain's declarations or installation.
- Their scripts/tests live under `mods/internal/{npm,uv}/scripts/`, not agents.
- `mods/internal/global-tools.nix` dispatches adapter-owned commands for activation
  and the `global-tools` CLI. It has no native installer policy or ownership ledger.

There is no universal capability schema. Native MCP/plugin/package shapes stay
under their agent. Duplication is preferable when agent APIs genuinely differ.
A shared utility may accept caller-supplied paths or data, but must not branch
on agent identity or own cross-agent policy.

## Ownership layers

Every realized asset is assigned by who else writes its target:

- **Layer 0 — only Nix writes it.** Skills, commands, Pi extensions/themes, and
  the `~/.agents/skills` store use `home.file`. Pinned content comes from flake
  inputs; repo-local content uses out-of-store symlinks. Home Manager provides
  revocation and rollback. Composed instructions, RTK resources generated in
  isolated Nix builds, and Vocal's Python runtime also belong here. RTK's
  package comes from `agents.rtkPackage`, not a Homebrew install.
- **Layer 1 — Nix and the tool share a config file.** Claude `mcpServers`, Codex
  `mcp_servers`, Pi `mcpServers`, and similar settings use activation-time
  managed-key replacement. Nix owns the managed key wholesale; sibling keys
  survive, but hand-added entries under the managed key do not.
- **Layer 2 — a native installer owns opaque state.** Claude plugins, Pi
  packages, npm tools, and uv tools use the tool's CLI. Stateful
  reconcilers may uninstall only assets recorded as managed by Nix.

These layers are adapter implementation details, not public option fields.

## Required invariants

- **Revocable:** removing desired state removes the corresponding managed asset
  on the next activation.
- **Ownership-safe:** Layer 2 pruning never removes user-installed inventory.
- **Convergent:** failed operations are retried; success state is recorded only
  after native validation.
- **Repairable:** unhealthy managed assets are repaired even when declaration
  fingerprints are unchanged.
- **Efficient:** healthy unchanged state performs no installer or registry work.
- **Corruption-safe:** unreadable ownership state never authorizes destructive
  cleanup.
- **Inspectable:** unsupported intent produces an evaluation error or warning,
  rather than being silently ignored.
- **System-symmetric:** checks and option evaluation cover every managed system
  equally unless a documented platform limitation makes that impossible.

## Machine identity

Host files explicitly select tooling overrides. `machineRoles` remains available
for other shared/platform configuration; it is distinct from
`MACHINE_NAME`, a hand-maintained shell-runtime variable, and from the
flake-declared hostname. Renaming a host must not silently remove role policy.

## Model runtimes

`mods/model-runtimes.nix` supplies the shared lightweight model selection.
`mods/internal/model-runtimes.nix` executes those declarations without selecting
models or inspecting machine roles. Individual
`homes/home-*.nix` modules override it and declare custom model bases/parameters.
Custom models retain the existing creation-only behavior: removing their
configuration does not automatically prune the resulting native model. `agents.providers.ollama` instead describes the endpoint
and model IDs exposed to agent adapters; the common and Loancrate profiles
choose the appropriate remote or local endpoint.

## Native installation is intentional

Keep npm and uv as general-purpose native installation paths. Agent-native
configuration and frequent package updates likewise remain adapter-owned; moving
these installations into Nix packages is not the simplification goal. Nix owns
the declarations, generation-bound scripts and activation trigger, while native
adapters own installation mechanics. Nix-owned resources such as RTK files and
Vocal's Python runtime remain unchanged.

Scute is installed from the npm registry as the exact version declared in
`mods/native-tools.nix`. Its Bun launcher uses the Nix-provided Bun runtime, while
the npm reconciler owns installation, repair, updates, and revocation.

SQLit is no longer selected. Its previously recorded uv ownership is sufficient
for uninstall on the next convergence of the new generation; no special removal
list or migration branch is needed. Editable toolbox discovery and the ability
to declare other uv registry tools remain available.

## Reconciliation and update modes

Global npm tools, Pi packages, uv tools, and Claude plugins use state-aware
reconcilers. All four share the agent-blind per-asset engine in
`mods/internal/scripts/lib/reconcile-installs.js`; their adapters own native
commands and health probes. Each successful asset retains its own progress, so
one failed sibling does not reinstall everything. Removed declarations are
pruned from recorded ownership, without a separately maintained removal list.
Missing state never grants ownership of undeclared native installations.

Healthy unchanged activation uses only local inspection: npm package metadata
and executable links, Pi's user inventory and package artifacts, and offline uv
receipts/interpreter inventories. These are installation-integrity checks, not
exhaustive transitive dependency validation. Unknown inspection fails visibly
instead of triggering an install loop; explicit repair can reinstall declared
assets, but cannot override corrupt ownership state. Atomic, content-aware
state writes and per-state-file locks protect progress and avoid mtime churn.

Vocal's dependency-only Python runtime is a Home Manager link to
`python3.withPackages` in `mods/neovim.nix`, not a mutable uv venv. The uv
adapter retains removal-only support for previously tracked Vocal requirements;
it leaves the legacy environment and unmanaged packages intact. No new Vocal
installations or repair state are created. `checks.<system>.vocal-runtime`
verifies interpreter selection ahead of project Python and imports `requests`.

Editable Python tools hash dependency metadata (`pyproject.toml` and `uv.lock`),
not source files. Code edits stay live without reinstalling. All tooling installer
scripts, including the model installer, use the immutable `mods/internal/native-scripts.nix` bundle belonging to the
installed generation—not an unrelated mutable checkout. TOML dependencies and
Workmux hook templates are also generation-bound; activation never bootstraps
npm dependencies into the checkout.

`GLOBAL_TOOLS_FORCE_REPAIR=1` forces reinstall/repair without changing desired state.
`GLOBAL_TOOLS_UPDATE=1` explicitly refreshes Claude marketplaces/plugins and reruns
Pi's native package reconciliation. `global-tools-check-updates` performs the
otherwise-network-free registry check for exact global npm versions; reported
versions update only when their declaration changes.

## Operations

```sh
global-tools status                # local inspection; does not mutate user state
global-tools status claude-settings # settings and RTK hooks; claude-mcp checks MCP
global-tools apply                 # normal convergence for the installed generation
global-tools repair                # force native repair; reapply writable config
global-tools repair pi-packages    # one component
global-tools check-updates         # report newer exact npm versions
global-tools update                # explicit mutable Claude/Pi refresh
```

The CLI and activation execute the same generated command files, in the same
order. Named `after` dependencies are validated for unknown IDs and cycles;
independent operations have deterministic name order. Dependencies specify order,
not success prerequisites. There is no "skip B if A failed" dependency mode;
if that need arises, design an explicit success-gating contract rather than
changing `after` semantics. Activation records failures and continues; the CLI
returns nonzero if any component fails. The report uses the same registry.

Independent files have separate operations (`claude-mcp`, `claude-settings`,
`claude-loancrate`, `codex-hooks`, `codex-config`, `pi-mcp`, `pi-settings`,
`pi-models`, `npm-config`). Same-file changes are projected together before
writing. A malformed file cannot block repair of an unrelated file.

`globalToolOperations` is shared infrastructure, not an agent option. Historical
`agents-nix` state paths remain for compatibility, but legacy `AGENTS_*`
activation overrides are retired. Use `GLOBAL_TOOLS_*` instead; the CLI clears
inherited repair/update overrides in status mode.

`files` checks only explicitly registered managed links, including skills,
instructions, RTK and Vocal. Adapters register the exact keys they declare, never
all files found under an agent's path prefix.
Only a Home Manager switch can restore those links; `global-tools repair` does not
reimplement linking or run a switch. Native checks are bounded local probes,
not proof that every extension can start or every transcription succeeds.
Config checks project each adapter's merge without writing; existing overlay
semantics still preserve native/manual fields outside managed keys.

RTK no longer runs during activation. Its native assets are generated with the
pinned `agents.rtkPackage` (currently 0.45.0), linked by Home Manager, and its
Claude hook is merged into writable settings. Instruction references are
composed once. Repo-local skills and user extension sources remain live links;
shared instruction edits now require a rebuild, deliberately.

Keep legacy state readers and removal-only Vocal cleanup until all four hosts
have migrated and the supported rollback window has closed. Record evidence in
[the migration gates](global-tools-migrations.md), including per-host MCP audits
and RTK upgrade reproducibility checks. Missing state never grants ownership. Shared Claude marketplace
registrations are installation inputs: removing a plugin does not delete a
marketplace containing manually installed plugins. Actual post-switch Vocal
transcription remains a manual verification step; checks make no model request.
