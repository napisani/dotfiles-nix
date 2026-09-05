# Context: declarative agent configuration

The agent configuration architecture is defined by:

- [ADR 0003](docs/adr/0003-declarative-agent-configuration-interface.md): typed
  desired state and profile composition
- [ADR 0001](docs/adr/0001-per-agent-modules.md): independent native adapters
- [ADR 0002](docs/adr/0002-layered-asset-management.md): ownership and
  revocation mechanisms

## Public desired state

`config.agents` is the interface for reviewing and changing a host's agent
configuration. It contains:

- enabled agents and their native MCP/settings declarations;
- selected shared and per-agent skill names plus manual-only policy;
- shared instruction source;
- exact-version global npm tools;
- shared provider endpoints/models;
- Claude marketplaces/plugins and Pi packages.

Common policy lives in `mods/agents/profiles/common.nix`. Role-specific policy
is composed through profiles such as `profiles/loancrate.nix`, selected from the
`machineRoles` special argument supplied by `lib/builders.nix`. Machine policy
does not belong in adapter declaration lists or `condition` fields.

The fully merged value is inspectable with `nix eval`. Each managed system
exports `checks.<system>.agent-config-resolved`, which serializes every host's
configuration so evaluation coverage is symmetric across architectures.

## Catalogs, profiles, and adapters

- `mods/agents/skills.nix` is a pure skill name-to-source catalog. It contains
  no machine, agent-selection, or manual-only policy.
- `mods/agents/skill-files.nix` validates selected names, resolves catalog
  sources, and provides agent-blind rendering/patching utilities.
- `mods/agents/profiles/*.nix` own desired-state policy.
- `mods/agents/{claude,codex,pi,opencode}.nix` are independent adapters. Each
  translates only its portion of `config.agents` into native state.
- `mods/npmx.nix` currently realizes `agents.globalNpmTools`.

There is no universal capability schema. Native MCP/plugin/package shapes stay
under their agent. Duplication is preferable when agent APIs genuinely differ.
A shared utility may accept caller-supplied paths or data, but must not branch
on agent identity or own cross-agent policy.

## Ownership layers

Every realized asset is assigned by who else writes its target:

- **Layer 0 — only Nix writes it.** Skills, commands, Pi extensions/themes, and
  the `~/.agents/skills` store use `home.file`. Pinned content comes from flake
  inputs; repo-local content uses out-of-store symlinks. Home Manager provides
  revocation and rollback.
- **Layer 1 — Nix and the tool share a config file.** Claude `mcpServers`, Codex
  `mcp_servers`, Pi `mcpServers`, and similar settings use activation-time
  managed-key replacement. Nix owns the managed key wholesale; sibling keys
  survive, but hand-added entries under the managed key do not.
- **Layer 2 — a native installer owns opaque state.** Claude plugins, Pi
  packages, RTK hooks, and analogous assets use the tool's CLI. Stateful
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

`machineRoles` is the source of truth for profile selection. It is distinct from
`MACHINE_NAME`, a hand-maintained shell-runtime variable, and from the
flake-declared hostname. Renaming a host must not silently remove role policy.

## Model runtimes

`mods/model-runtimes.nix` is a sibling domain, not an agent adapter. It selects a
local runtime backend (`ollama` or `mlx-lm`) and declaratively manages that
runtime's model cache. `agents.providers.ollama` instead describes the endpoint
and model IDs exposed to agent adapters; the common and Loancrate profiles
choose the appropriate remote or local endpoint.

## Reconciliation and update modes

Global npm tools, Pi packages, uv tools/venvs, and Claude plugins use state-aware
reconcilers. Pi/npm/uv share the agent-blind per-asset engine in
`mods/dotfiles/scripts/lib/reconcile-installs.js`; their adapters own native
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

Editable Python tools hash dependency metadata (`pyproject.toml` and `uv.lock`),
not source files. Code edits stay live without reinstalling. Claude/Pi installers,
Pi settings, npm and uv activation use the immutable `mods/native-scripts.nix`
bundle belonging to the evaluated generation—not an unrelated mutable checkout.

`AGENTS_FORCE_REPAIR=1` forces reinstall/repair without changing desired state.
`AGENTS_UPDATE=1` explicitly refreshes Claude marketplaces/plugins and reruns
Pi's native package reconciliation. `agents-check-updates` performs the
otherwise-network-free registry check for exact global npm versions; reported
versions update only when their declaration changes.

RTK initialization is the remaining repeated native operation to optimize. A
future update checker should query upstreams outside normal activation and
propose declaration changes, keeping freshness checks separate from
convergence.
