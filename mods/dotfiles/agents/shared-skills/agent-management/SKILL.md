---
name: agent-management
description: Manage agent settings, MCP, skills, instructions, packages and RTK in this dotfiles repo. Use before changing mise app declarations, skill preparation, RTK setup, shared-file writers or native package hooks.
---

# Agent configuration

## Choose the owner first

- **Prebuilt user CLIs/runtimes, configuration and deployment:** `mods/dotfiles/mise/config.toml`,
  `mise/apps/` native fragments, and `homes/<machine>/mise.toml` overlays.
- **Artifact builds:** public Nix modules own monorepo tools through local
  `path:` inputs, base userland and documented exceptions. Portable mise runtimes
  prepare skills and app settings; skills and RTK resources are not Nix-built.
- **Runtime state and secrets:** applications. Shared files use native merges
  or app-aware writers, never whole-file templates.

Before lifecycle/ownership changes, read
`docs/contracts/declarative-tooling.md`; before deployment/cleanup, read
`docs/contracts/mise-cutover.md`. ADR 0004 supersedes the former
Nix application-settings interface. `config.agents` no longer exists.

## Change native app configuration

Find its native fragment/template under `mods/dotfiles/mise/apps/`.
MCP maps use each application's native shape in `common/` or `work/`;
Pi settings, script approvals, Claude settings and npm authentication live beside
those profiles. Add only environment references, never literal credentials.

Mise merges plain settings natively, including work-host Loancrate settings.
The Deno writer `mods/dotfiles/mise/runtime/configure-apps.ts` reads authored
files for removal-sensitive policies and preserves app-written siblings and manual
hooks. Its `@std/toml` dependency is vendored and pinned in `deno.lock`.
MCP maps and script approvals are owned wholesale, so promote needed manual
entries before applying. Native additive merges cannot implement revocation.
File history/recovery capture is disabled because merge targets can contain
credentials. Native merges write in place; see the contract before changing that.
Pi's `settings.json` includes app-written `packages`: preserve them.

For authored files, add a mise dotfile declaration. Pi themes/extensions use
`symlink-each` directory entries; test/spec files are excluded.
Whole-file templates are appropriate only when the entire destination is owned.
Use data-only template reads: mise status/diff can render templates too.

Keep the core portable. Standalone bootstrap links its sources and plugins;
`runtime:prepare` installs the locked uv environment without a Nix fragment.
The host TOML's `vars.agent_profile` selects common/work writer and skill inputs.
Native INI merges own npmrc and preserve unmanaged authentication/registry keys.

Host overlays are linked as global `config.local.toml`, which can override the
main global file. Pinned mise's `conf.d` entries have lower precedence.
Dotfile source paths are not template-rendered; use explicit paths through the
bootstrap `~/.config/mise/dotfiles` source link.

## Prepare skills and initialize RTK
`mods/agents/skills.json` declares source paths, common/work selections, required
rewrites and manual-only intent. Remote revisions belong in native
`[bootstrap.repos]` with exact commits; local sources stay in the monorepo.
Use the dependency workflow and audit changed upstream skill content.

`skills:prepare` runs offline as a dependency of `apps:configure`. Missing/stale repositories
preserve the last good view (empty on first run); dirty checkouts, origin mismatches
and invalid available content fail. `skills:sync` fetches sources then applies the
skill group through the configuration task. `sys-update apply` and
`sys-update skills` propagate its failures. Preparation validates source
revisions and metadata, stages complete directories, adds native Codex/Pi
controls, and emits Claude overrides. Unmodified local skills remain live;
transformed content is refreshed on the next apply, without a rebuild.
Native groups deploy and revoke owned links while preserving manual neighbors.

`rtk:setup` resolves the pinned mise executable and uses upstream Claude/Pi/Codex
initializers. It rejects links and modified RTK files, disables custom-filter
trust, and never runs during activation. Writers own Workmux hooks, not RTK hooks.
Before the first setup or an RTK upgrade, follow the explicit ownership handoff
in `docs/contracts/mise-cutover.md#skills-and-rtk-cutover`. Preserve
the existing Homebrew executable unless its cleanup is separately approved.

## Native packages

Tools and extension packages are independent mise declarations:

```toml
[tools]
"npm:@scope/cli" = "1.2.3"

[bootstrap.packages]
"claude:plugin@marketplace" = "latest"
"pi:npm:some-extension" = "1.2.3"
"pi:git:github.com/owner/repo" = "v1.2.3"
```

Quote every tool key. Registry/aqua/GitHub, npm and pipx versions belong to
`mise-tools`, `npm-tools` and `python-tools` dependency domains respectively.
Tool-pin updates regenerate checkout-owned core/host lockfiles and native
sidecars; after manual edits run `scripts/lock-mise-fleet.sh`. Keep lockfile
symlink targets present; do not symlink sidecar directories separately.

Use existing tool backends, including `pipx:<package>` for Python CLIs; Lua
plugins only handle native extension lifecycles. Use exact npm versions or
explicit Git refs. Marketplace sources belong in native Claude settings;
hooks register missing requested repos before install/upgrade. Inventory probes
are bounded; mutations retain native no-timeout behavior.

## Apply and retire

```sh
mise -C "$HOME" run skills:sync
mise -C "$HOME" bootstrap --only dotfiles
mise -C "$HOME" bootstrap dotfiles status
mise -C "$HOME" bootstrap packages status
mise -C "$HOME" bootstrap packages prune --manager pi --dry-run
```

Use `mise -C "$HOME" run apps:configure` for managed-key reconciliation, skill
preparation and provider setup. Native dotfiles apply handles declared links and
merges; the post-tools bootstrap hook runs the complete configuration task.
`sys-update apply` stops on failure. Runtime/plugin and authored data edits need
no Nix switch; system build inputs do.

Managed-key removal follows the writer's contract. Stale skill-group links are
removed by native apply. Plain top-level dotfile omission leaves its applied
link: explicitly retire owned paths with native `mode = "absent"` or reviewed
`unapply` before removing the declaration.

Package pruning is explicit: name `claude` or `pi`; the default
package prune targets Homebrew. Ordinary tools use `mise prune --tools`.
Preexisting packages remain unowned; other trusted configs can retain packages.
Preserve legacy ledgers and native data. Interrupted installation can remain unowned. Use native semantics, not another
ownership/retry/recovery engine.

## Verify

From the monorepo root:

```sh
nix flake check ./pub/dotfiles-nix --all-systems --no-build
```

This evaluates all hosts, not their runtime behavior. Follow
`mods/dotfiles/mise/runtime/mise/README.md` for actual-mise disposable-profile tests and
`checks/fixtures/config-writers.cjs` for configuration deployment. Keep existing
managed-key, privacy, idempotence, malformed-input and ownership tests.
No real host activation or active-profile native operations without approval.
