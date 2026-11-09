# Declarative tooling: architecture and operations

## Owners

| Resource | Owner |
|---|---|
| OS/services, fonts, NixOS base userland, Nix tooling, login Bash, Mac GnuPG and retained monorepo builds | Nix |
| macOS preferences | nix-darwin |
| User CLIs/runtimes, Mac base userland, Neovim/provider/LSP/DAP tools and authored configuration | Portable mise |
| nil language server | Nix system packages |
| GUI applications and native libraries | Mise native package declarations, after reviewed ownership transfer |
| Docker Desktop installation and CLI integration on maclab (approved compatibility exception) | Docker Desktop / operator |
| Runtime state, credentials and settings outside managed keys | Applications |

Home Manager is absent from the builders and inputs. Each host has one selected
system package set; Intel maclab retains the last Intel-compatible Nix release.
The [roadmap](../superpowers/plans/2026-11-05-nix-boundary-roadmap-plan.md) records
implementation and deployment evidence separately. Evaluation does not prove
activation.

## Declarations and deployment

- `mods/dotfiles/mise/config.toml`: shared tools, native packages, repository pins,
  dotfiles and tasks. No Nix-generated configuration fragment is required.
- `homes/<machine>/mise.toml`: host policy, linked as global `config.local.toml`.
  It includes shared roles from `mods/dotfiles/mise/roles/` through the
  `~/.config/mise/dotfiles` link.
- `mods/dotfiles/mise/apps/`: native desired settings/MCP, authentication
  references, approvals and instruction templates.
- `mods/agents/skills.json`: source paths, selections, required rewrites and
  manual-only intent. Remote commits live in mise repository declarations.
- `mods/dotfiles/mise/runtime/`: the Python configuration writer, native plugins
  and the locked uv environment both run in. Preparation runs with mise-selected
  Python, not Nix wrappers.

`bootstrap.sh [MACHINE]` installs official standalone mise >=2026.11.2, checks
collisions and links the five global config/source/lock destinations plus native
Claude/Pi plugins. Matching links survive retries; changed or symlinked ancestors
and a remaining `conf.d/nix.toml` require review.

The post-tools task prepares dependencies, skills and the dedicated Neovim Python
provider, then reconciles application settings. Skills pending fetch retain the
last-good view (empty on first installation); dirty sources or invalid available
metadata fail. `skills:sync` explicitly fetches repositories and reapplies the
prepared view. Local authored links remain live and manual neighbors survive.

`sys-update apply` switches the system when available, bootstraps userland and
synchronizes skills in HOME. It stops on failure and refreshes the caller's
current-project environment afterward. `nixswitch` is a pure system switch.
There is no soft-failing Home Manager installer dispatcher. RTK initialization
is separate and explicit.

Mise owns Neovim and its LSP/DAP tools rather than Mason. The provider environment
is outside the checkout; Neovim disables Ruby and adds mise shims itself for GUI
launches. System-owned nil is tested separately from Nix-free editor acceptance.

OmniWM settings remain a writable copy. Its ARM-host cask and native mise
LaunchAgent preserve RunAtLoad, KeepAlive and logs. The native label is
`dev.mise.omniwm`; the migration harness preserves and retires the legacy
`org.nix-community.home.omniwm` plist/job before applying it. A bootstrap
preflight rejects remaining legacy ownership. Direct part commands bypass hooks,
so they are not a safe substitute for the first reviewed handoff.

### Shared files are not templates

Only wholly owned inputs and instructions use whole-file rendering.
Native `merge = true` edits manage Claude extra settings, Pi settings, the
remote relay, Codex feature flags, work-host Loancrate settings and npmrc (INI). npmrc preserves unmanaged
registry/authentication keys and literal environment-variable references. Edit keys end with an id, for example
`"~/.pi/agent/settings.json/settings"`; `template = "tera"` renders a merge
source. Objects merge recursively, arrays/scalars replace, and omitted keys
remain. Pi-written `packages` and other app-owned siblings survive. New targets
use `permissions = "0600"`; existing file permissions are preserved.

Custom writers remain for whole-map MCP replacement, script-approval
revocation, Workmux hook/Claude skill-override replacement, Codex managed-hook state,
and transitional Pi skill-path retirement. The cutover notes define when that
retirement writer can be removed.
Removing a declared MCP server, script approval or skill override removes it
from the managed map. Native merge alone cannot implement that policy.
Malformed source/target JSON or TOML fails before that file is changed.

Native merges write in place, not atomically; apply while applications are not
rewriting those files. There is no cross-file transaction. The remaining
writers use atomic replacement. This native-write trade-off is intentional.

`[settings.history].enabled = false` prevents mise from capturing credentials
in file history or temporary recovery preimages, including interrupted applies.
This disables owned-file history too; existing history is not deleted.
Do not re-enable it without reviewing shared merge targets and recovery storage.
Package ownership/pruning remains mise-owned and independent of file history.

Authored fragments contain references such as `${NODE_AUTH_TOKEN}`, not
credentials. Templates use data-only reads and JSON encoding, never `exec()`;
native status/diff can render them. A shared-file diff may display app-written
secrets: inspect locally rather than copying it into logs. Other trusted configs
can change settings or use effectful templates; this is not sandboxing.

TOML, native app fragments and ordinary linked file edits need no Nix switch.
Apply configuration with `mise -C "$HOME" bootstrap --only dotfiles`.
Use `mise -C "$HOME" run apps:configure` for writer reconciliation and provider preparation.
Runtime and plugin sources are portable; only system/build-input changes require a Nix switch.

Native group apply removes stale owned skill links. For a top-level dotfile,
omitting its declaration leaves its existing link; explicitly retire it with
`mode = "absent"` or review native `unapply` before removing its declaration.
Never blanket-delete unknown files or add a parallel ownership ledger.

Global tool resolution uses `locked = true` with `locked_scopes = ["global"]`;
project configurations keep their own lock policy. No active feature requires
`experimental = true`.

## Native operations

Use `-C "$HOME"` for host defaults rather than the current project's overrides:

```sh
mise -C "$HOME" ls --current
mise -C "$HOME" bootstrap packages status
mise -C "$HOME" install
mise -C "$HOME" bootstrap packages apply

mise -C "$HOME" bootstrap packages upgrade --manager claude
mise -C "$HOME" bootstrap packages upgrade --manager pi
```

Quote every `[tools]` key. Generic dependency families are `mise-tools`
(registry/aqua/GitHub/Go/conda and tagged GitHub HTTP scripts, including Claude and Codex), `npm-tools` and `python-tools`
(`pipx:`); TPM uses `mise-repos`, and application extensions use `pi`.
Move pins with `make deps-update DOMAIN=<family> PROJECT=dotfiles-nix`.
Tool-pin updates automatically run the native fleet-lock task before verification.
A standalone clone edits TOML and runs `scripts/lock-mise-fleet.sh`.

`mise.lock` beside the core TOML and each host's `mise.local.lock` are checkout-owned.
`mise lock -g --platform macos-arm64,macos-x64,linux-x64` updates the current host;
`scripts/lock-mise-fleet.sh` applies that command to all four configurations in a
disposable HOME. Existing file symlinks are preserved. Keep their targets present:
a dangling link is replaced by native mise. Dependency sidecars remain beside the
resolved target, so do not add a separate symlink for the sidecar directory.
Commit native `.mise/locks/` sidecars with their lockfile. Binary entries require
URLs/checksums for their selected fleet platforms; pipx entries carry native uv locks. Native
npm shell-out records exact top-level versions but does not lock transitives.
Lock resolution is not proof of foreign-platform execution.
`sys-update claude` delegates to the Claude upgrade command above.
`sys-update brew` upgrades declared `brew` and `brew-cask` packages through
mise; it does not prune or clean up unrelated Homebrew packages. The Homebrew
installation stays on disk, and casks it still owns need a reviewed transfer.
Use native application diagnostics or explicit reinstall/upgrade commands for
damage beyond these local presence/version checks; there is no repair engine.

**Package pruning is explicit**, not part of a switch or package apply. Preview before
confirming removal:

```sh
mise -C "$HOME" prune --tools --dry-run
mise -C "$HOME" prune --tools --yes
mise -C "$HOME" bootstrap packages prune --manager claude --dry-run
mise -C "$HOME" bootstrap packages prune --manager claude --yes
```

Repeat package prune for `pi` as needed. Always name
the manager: the default bootstrap package prune targets Homebrew.

Normal mise semantics apply. Projects can override global tool versions; other
trusted tracked configs can retain tools/packages. This configuration does not
strip inherited mise settings or isolate ownership from the user's other configs.
The login profile uses native `mise env` so child scripts inherit real tool
paths rather than paying shim startup per command. Interactive shells retain
stock activation for directory changes; shims remain the bootstrap/GUI fallback.
Launchd jobs with independent environments can use `mise exec -- <command>` for
loop-heavy work. There are no fixed host launchers. Native package
plugins manage user-global application state even when invoked from a project.

## Package behavior

**Agent executables.** Existing aqua backends install Claude Code and Codex;
Pi keeps its existing npm backend. These are tool declarations, distinct from
extension package plugins. Initial Claude/Codex pins match the versions recorded
in local Homebrew metadata; Homebrew cask declarations are removed. No package
plugin is used to install these executables.

**npm CLIs.** The built-in npm backend owns separate versioned prefixes. Native
npm retains npmrc registry/authentication behavior. Trusted pinned tools enable
build scripts with `allow_builds` and the native npm compatibility argument.
Normal shims and `mise exec` select versions and preserve caller cwd/arguments.

**Python.** Install globally available, isolated CLIs with mise's built-in
`pipx:<package>` tool backend and an explicit version. There is no custom
editable installer, toolbox auto-discovery or system-Python mutation.

**Claude.** Only user-scoped plugins are managed. Versions are `latest`; declare
marketplace sources through native Claude settings. Before install/upgrade,
the plugin lists registered marketplaces and adds missing requested GitHub repos
from `extraKnownMarketplaces`; there is no second source list. Upgrade then
refreshes only requested marketplaces and their plugins. Existing/manual
marketplaces are not removed. Inventory probes have a 120-second timeout;
install, upgrade and uninstall use the native no-timeout default. Removal uses `--keep-data`, but Claude
can still delete plugin options/secrets from its secure store on last-scope
uninstall. Cutover never automatically reinstalls existing plugins.

**Pi.** Stable identities exclude the version/ref:

```toml
[bootstrap.packages]
"pi:npm:some-package" = "1.2.3"
"pi:git:github.com/owner/repo" = "v1.2.3"
```

Only exact npm versions or explicit Git refs are used. Native Pi actions run in
HOME's user scope; bare `pi update` is never used. Native npm-root finalization
follows package mutations to repair shared peer resolution. npm `allowScripts`
is mise-owned application configuration, not a lifecycle input. After changing approvals,
explicitly refresh Pi packages if their installation work needs rerunning.

## Ownership and limitations

RTK initialization is explicit: `mise -C "$HOME" run rtk:setup`. It resolves
`aqua:rtk-ai/rtk` through mise and initializes Claude, Pi and Codex with custom-filter
trust disabled. Shared-file writers preserve RTK hooks; instruction templates keep
the upstream `RTK.md` references. The task rejects links and non-stock RTK files
before real initialization. See [cutover notes](mise-cutover.md#skills-and-rtk-cutover).

Mise claims missing-to-installed transitions. Preexisting packages remain
unowned, including old reconciler installations; removing declarations does not
uninstall those packages. First package status can create mise's own tracking,
migration marker and empty cache directories; it does not mutate packages.
Concurrent applies serialize native mutations, but a queued plan may replay
an install after the first apply completes.

No local ownership importer, retry journal, lock or recovery engine supplements
mise. An interrupted first install can finish natively before ownership is
recorded; retry may leave it unowned, and later prune preserves it. This accepted
native behavior has a regression test.

Keep legacy ledgers and installations intact; see the
[cutover notes](mise-cutover.md). Neither a switch nor an ownership
record proves application startup, a complete dependency closure, transactional
rollback or fleet deployment. Keep native manager executables available until
their final package prune has completed.

Mise must be at least 2026.11.2, enforced by the global `min_version`.
The official standalone installation owns the executable; Nix neither packages
nor launches it during activation.
Evaluation is not proof of Intel compilation or Intel/Linux runtime behavior.

## Verification

`checks/native-installs.nix` asserts system/userland ownership and Home Manager's
absence. Portable behavior runs through the project's `mise run test`: native
mise, isolated HOME directories, a loopback registry, writer/credential/privacy
checks, bootstrap, shell, skill and migration fixtures. Cold runtime, LSP/DAP and
PostgreSQL acceptance have explicit tasks. LaunchAgent tests use fake launchctl
and deny the real executable with a macOS sandbox.

See `mods/dotfiles/mise/runtime/mise/README.md`. Evaluate all systems with
`nix flake check --all-systems --no-build`; activation requires explicit
host-specific authorization and separate live functional evidence.
