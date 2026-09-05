# Put a declarative desired-state interface in front of agent adapters

**Status:** accepted

**Date:** 2026-09-04

## Context

The agent configuration is declarative in the broad sense—Nix ultimately
produces the files and activation steps—but the desired state is not easy to
inspect.

Today, policy and realization are mixed together:

- `skills.nix` is a source catalog, agent/system selection policy, manual-only
  capability table, and `home.file` renderer.
- `claude.nix`, `codex.nix`, `pi.nix`, and `opencode.nix` mix declarations with
  target paths, activation DAG ordering, repair steps, and native installer
  details.
- Machine-specific declarations are expressed as repeated `condition` fields
  inside catalogs and per-agent lists.
- Global agent CLI declarations live separately in `npmx.nix`.
- Some installed content is implied by directory enumeration rather than named
  in one desired-state value.

ADRs 0001 and 0002 improved ownership and revocation. Per-agent modules now own
their native installation stories, and each asset uses the mechanism appropriate
to who writes its target path. Those decisions remain useful implementation
constraints. They do not, however, provide a small interface through which a
machine declares its agent configuration.

The intended user experience is:

> For any host, inspecting one evaluated Nix value should show which agents are
> enabled and the skills, instructions, MCP servers, plugins, packages, hooks,
> and settings each will receive.

A caller should not need to understand activation ordering, state-file schemas,
installer retries, path repair, or JSON/TOML merge mechanics to declare that
state.

## Decision

Introduce typed Home Manager options under `agents.*` as the public desired-state
interface. Existing per-agent modules become adapters that consume this value
and realize it through the Layer 0/1/2 ownership mechanisms.

The architecture has four parts:

```text
machine/profile declarations
            │
            ▼
┌──────────────────────────────┐
│ config.agents desired state  │  public interface
└──────────────────────────────┘
            │
            ▼
┌──────────────────────────────┐
│ per-agent adapters           │  Claude, Codex, Pi, OpenCode, global tools
└──────────────────────────────┘
            │
            ▼
┌──────────────────────────────┐
│ ownership mechanisms         │  home.file, managed-key merge, CLI reconcile
└──────────────────────────────┘
            │
            ▼
┌──────────────────────────────┐
│ native files and tool state  │
└──────────────────────────────┘
```

### Public interface

The implemented interface is:

```nix
agents = {
  enable = true;
  instructions = ./AGENTS.md;

  skills = {
    shared = [
      "tdd"
      "context7"
      { name = "brainstorming"; manualOnly = true; }
      { name = "prototype"; manualOnly = true; }
    ];
    perAgent = {
      claude = [ ];
      codex = [ ];
      pi = [ ];
      opencode = [ ];
    };
  };

  globalNpmTools = {
    "@ellery/terminal-mcp" = "0.5.1";
    "@playwright/cli" = "0.1.19";
  };

  providers.ollama = {
    baseUrl = "https://ollama.example/v1";
    models = [ "qwen3:1.7b" ];
  };

  claude = {
    enable = true;
    mcpServers = { };
    pluginMarketplaces = [ ];
    plugins = [ ];
    settings = { };
    loancrateConfig = null;
  };

  codex = {
    enable = true;
    mcpServers = { };
    settings = { };
  };

  pi = {
    enable = true;
    mcpServers = { };
    packages = [ ];
    settings = { };
    skillPaths = [ ];
  };

  opencode = {
    enable = true;
    mcpServers = { };
    plugins = [ ];
    settings = { };
  };
};
```

Agent-native values such as `mcpServers` and `settings` intentionally keep their
native nested shapes. The typed outer structure stays small while preserving
these properties:

1. `config.agents` describes desired state, not activation procedure.
2. Agent-native declarations remain under their agent.
3. Exact-version mutable packages are represented structurally rather than as
   strings containing `@latest`.
4. Unsupported intent is reported during evaluation or activation rather than
   silently ignored.
5. A host's fully merged configuration can be inspected with `nix eval`.

### Skill catalog and skill policy are separate

The skill catalog becomes a pure name-to-source registry. It answers only:

> Given a skill name, where does its content come from?

For example:

```nix
{
  tdd = {
    input = inputs.mattpocock-skills;
    path = "skills/engineering/tdd";
  };

  context7 = {
    input = inputs.intellectronica-agent-skills;
    path = "skills/context7";
  };
}
```

Catalog entries may describe pinned flake content or repo-local content. They do
not decide which machines or agents receive a skill, whether it is manual-only,
or how it is linked.

Those choices belong to `config.agents.skills`. Skills shared by all enabled
agents are listed once. Per-agent additions are explicit. A plain string is the
concise form of `{ name = "..."; manualOnly = false; }`; exceptional
`manualOnly = true` policy is colocated with that skill's selection. Adapters
translate the policy to each agent's native mechanism.
If an enabled agent cannot honor that policy, the module emits a visible warning
or assertion instead of silently weakening the declaration.

The renderer that turns resolved skill names into `home.file` entries moves out
of the catalog and into adapter support code.

### Machine-specific policy uses module composition

Baseline declarations live in a common agent profile. Work, personal, and other
role-specific profiles add declarations through ordinary Nix module merging.
The profile selection is driven by the existing flake-declared machine roles.

For example:

```nix
# Common profile
agents.skills.shared = [ "tdd" "context7" ];

# Loancrate profile
agents.skills.shared = [
  "loancrate-standup-prep"
  "loancrate-lc-script"
];

agents.claude.mcpServers.linear = {
  type = "http";
  url = "https://mcp.linear.app/mcp";
};
```

This replaces repeated entry-level `condition = isLoancrateMac` fields with a
small number of visible profile overlays. Host modules may still override or
extend the merged options when a machine genuinely differs from its role.

### Per-agent adapters remain independent

ADR 0001's rejection of a cross-agent installer script still stands. The
adapters for Claude, Codex, Pi, and OpenCode independently translate their
portion of `config.agents` into native state.

There is no universal plugin/capability schema. An MCP server or capability may
require different native declarations for different agents, and those
agent-specific shapes remain visible under `agents.<agent>` rather than being
hidden behind conditional translation logic.

Sharing is appropriate where the domain is genuinely uniform:

- skill names and sources;
- shared instructions;
- exact-version global CLI tools;
- agent-blind file/state utilities.

### Ownership layers become private implementation detail

ADR 0002's ownership model remains unchanged:

- Nix-only paths use `home.file`.
- Tool-mutated config files use full managed-key replacement.
- Native installers use state-aware CLI reconcilers.

The public interface does not expose these layers. Each adapter chooses the
correct mechanism and is responsible for:

- revoking removed declarations;
- preserving assets outside its ownership;
- recording convergence only after successful operations and validation;
- repairing missing or unhealthy managed assets;
- avoiding installer or network work for healthy unchanged state;
- supporting an explicit forced-repair path.

The Pi and global npm reconcilers introduced during the state-aware
reconciliation work remain valid. They move behind the adapter interface rather
than defining that interface.

## Module layout

The implemented layout keeps the existing filenames while making their roles
explicit:

```text
mods/agents/
  default.nix                 orchestration and cross-option assertions
  options.nix                 typed public interface
  skills.nix                  pure skill name → source catalog
  skill-files.nix             agent-blind skill resolution/rendering support
  profiles/
    common.nix                baseline desired state
    loancrate.nix             work-role desired-state overlay
  claude.nix                  Claude native adapter
  codex.nix                   Codex native adapter
  pi.nix                      Pi native adapter
  opencode.nix                OpenCode native adapter
  managed-config-lib.nix      ownership/reconciliation utilities
```

`mods/npmx.nix` is currently the adapter for `agents.globalNpmTools`; native
reconciler scripts remain under `mods/dotfiles/agents/scripts/`. Physical
location is secondary to the boundary: declarations live above adapters and
reconciliation mechanics live below them.

## Migration

Migrate incrementally without changing installed state:

1. Define the typed `agents.*` option tree and an evaluation check for its
   resolved value.
2. Populate common and role-specific profiles with today's declarations.
3. Split the current `skills.nix` into a pure source catalog and skill-rendering
   support code. Make adapters consume resolved skill names.
4. Convert one agent module at a time into an adapter consuming
   `config.agents.<agent>`, comparing generated activation/file outputs during
   each step.
5. Move global npm declarations and the existing state-aware reconciler behind
   the same public interface.
6. Remove old declaration lists only after every consumer uses the options.
7. Resume Claude plugin, RTK, and explicit update/repair optimization behind the
   adapter interfaces.

During migration, avoid a second source of truth. A declaration moves to
`config.agents` in the same change that removes its old list.

## Verification

The migration is complete when:

- `nix eval` can display the resolved agent configuration for every host;
- the flake check forces all merged option and activation values;
- existing Layer 0 links and Layer 1 managed keys are unchanged;
- Layer 2 tests prove managed-only pruning, failure retry, corrupt-state safety,
  health repair, and healthy no-op behavior;
- removing a declaration from a profile revokes only the corresponding managed
  asset;
- no adapter owns cross-agent policy or branches on agent identity.

## Superseded decisions

This ADR supersedes only the following earlier conclusions:

- ADR 0002's rejection of typed `options.agents.*`; the growing configuration
  surface now makes the interface and validation worth the boilerplate.
- ADR 0001/CONTEXT language implying that declarations must live in the same
  file as an agent's realization. Each adapter still owns its complete native
  realization, but desired-state declarations now live above adapters.
- `skills.nix` as both catalog and rendering utility. The catalog becomes pure.

The per-agent ownership decision from ADR 0001, the no-universal-capability
abstraction decision, and all Layer 0/1/2 ownership rules from ADR 0002 remain
in force.

## Consequences

- A host's agent setup becomes reviewable as data without reading activation
  code.
- Machine-role differences become explicit profile overlays.
- Adapter and reconciliation complexity remains necessary, but is localized
  below a small interface.
- Typed options add module boilerplate and require a staged migration.
- Some duplication remains in per-agent native declarations. This is preferred
  over a shallow abstraction that hides real differences between agents.
- Adding a skill requires registering its source and selecting it in desired
  state. The extra explicit step is the cost of making installation inspectable.
