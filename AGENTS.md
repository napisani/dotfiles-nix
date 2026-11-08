# Dotfiles agent guidelines

## Ownership

- Nix configures systems and base packages. `systems/` holds OS policy;
  `mods/base-packages.nix` holds shared Nix tooling and the retained local
  monorepo builds. `mods/system-packages.nix` adds NixOS base utilities.
- nix-darwin owns macOS preferences. Keep the narrow Spotlight hotkey edit:
  replacing its entire defaults dictionary destroys unrelated user bindings.
- Portable mise owns user tools, editor providers, agent configuration and
  deployment. Shared declarations are in `mods/dotfiles/mise/config.toml`;
  host overlays are `homes/<machine>/mise.toml`, which include shared roles from
  `mods/dotfiles/mise/roles/`. Roles cannot declare dotfiles.
- Home Manager is not a deployment layer. Keep user configuration out of system
  activation. `nixswitch` switches only Nix; `sys-update apply` orchestrates the
  system switch, standalone bootstrap and HOME-scoped skill synchronization.
- The shell profile derives `DOTFILES_DIR` from the canonical mise source link.
  `mods/dotfiles/shell/bash/lib/machine.sh` maps hostnames to machine names for
  both the profile and `bootstrap.sh`; a machine is any `homes/<machine>/`.

Before ownership changes, read `docs/contracts/declarative-tooling.md` and
`mise-migration/README.md`. Before editing agent assets or reconciliation, read
`mods/dotfiles/agents/shared-skills/agent-management/SKILL.md`.

## Editing

- App fragments: `mods/dotfiles/mise/apps/`. Shared mutable JSON/TOML files use
  managed-key writers, not whole-file templates. Preserve credentials and sibling
  keys; keep secrets out of tracked fragments and diagnostics.
- Runtime implementation: `mods/dotfiles/mise/runtime/`; native package plugins
  live under `runtime/mise/plugins/`. Keep host selection in host overlays.
- Skills: `mods/agents/skills.json` plus pinned mise repository declarations.
  Preserve live authored links. Missing source checkouts defer to the last-good
  view; invalid or dirty sources fail rather than silently replacing it.
- RTK initialization is the explicit `rtk:setup` task, not a switch side effect.
- Tool pin edits require `scripts/lock-mise-fleet.sh` and lock coverage checks.
  Follow the monorepo dependency workflow; never update every flake input at once.
- Shell changes require `mods/dotfiles/shell/OWNERSHIP.md` and its smoke tests.
- Neovim changes require `mods/dotfiles/nvim/AGENTS.md`. Mise owns Neovim, its
  dedicated Python provider and LSP/DAP tools; nil remains a Nix system package.
  Preserve plugin locks unless a plugin update is explicitly requested.
- Karabiner source is `mods/dotfiles/karabiner/`. Run `deno task build` there and
  include its generated `../karabiner.json` and Look catalog changes. Generation
  writes beside its source; deployment remains mise's job. Never replace the
  user's config as a side effect of generation.

## Validation

From the monorepo root run `make check FILTER=dotfiles-nix` and
`make lint FILTER=dotfiles-nix`. The project's `mise.toml` defines portable tests,
lock checks, cold runtime, editor LSP and PostgreSQL acceptance commands.
Native GUI lifecycle fixtures must not activate the real desktop services.

Evaluate all hosts and dry-build their system outputs:

| Host | Output |
|---|---|
| Personal ARM Mac | `darwinConfigurations.nicks-mbp.system` |
| Work ARM Mac | `darwinConfigurations.Nicks-Loancrate-MacBook-Pro.system` |
| Intel maclab | `darwinConfigurations.maclab.system` |
| Supermicro | `nixosConfigurations.supermicro.config.system.build.toplevel` |

Use `nix flake check ./pub/dotfiles-nix --all-systems --no-build` and
`nix build --dry-run --no-link ./pub/dotfiles-nix#OUTPUT`. Stage new source files
before Nix evaluation. Format edited Nix files and run focused tests first.
Activation requires explicit user authorization for the particular host; a
passing dry build does not prove deployment or application functionality.

## Migration safety

While a rollout is live, change declarations only through the runbook's
branch-sharing rules in `mise-migration/README.md`. Retain backups and failed checks. The harness preserves
retired Home Manager generations as backup GC roots and leaves general Nix
profiles (including Tdarr) alone. OmniWM's legacy agent must be retired before
mise installs its `dev.mise.omniwm` agent. Direct launchd subcommands bypass
bootstrap hooks: use the reviewed harness for an ownership handoff.

Keep package cleanup explicit. Never infer ownership from an installed package,
remove manual data, or use zap/force/GC to bypass an incomplete migration.
System evaluation, isolated fixtures and live functional verification are separate
pieces of evidence; report what was actually exercised.

## Supermicro and workarounds

Before changing GitOps, read the monorepo's `docs/system-map.md` and
`docs/contracts/gitops-sync.md`, then inspect `priv/kube-home-lab/`. Supermicro
owns scheduling and prerequisites; the private subtree owns desired Kubernetes
state and reconciliation. Preserve its `nix develop` entry point until the
separate project-shell migration is approved.

Record upstream workarounds and their removal conditions in `WORKAROUNDS.md`.
Keep project-shell replacement, the mono backend and repository splitting on
separately approved tracks.
