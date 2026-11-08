# Use normal global mise for user tools and configuration

**Status:** accepted

Each tool has one declaration owner on each platform:

- **Mise tools:** prebuilt user CLIs and language runtimes, using ordinary global
  TOML, state, shims and existing backends.
- **Mise package plugins:** application-owned inventories (Claude plugins and Pi
  packages), through minimal native Lua adapters.
- **Nix:** OS/services, fonts, Nix tooling, the NixOS base userland,
  source-built/patched artifacts and every local monorepo tool. Macs use mise
  for base userland, retaining their Nix login shell and GnuPG.
- **Mise native package managers:** GUI applications and native libraries
  through `brew-cask:` and `brew:`. Existing Homebrew casks remain
  Homebrew-owned until the operator transfers them; maclab is the first pilot.
- **Mise editor tooling:** Neovim, its dedicated pynvim environment, language
  servers and debug adapters. Ruby is disabled; nil remains Nix-owned.

## Boundary roadmap

The [2026-11-05 roadmap](../superpowers/plans/2026-11-05-nix-boundary-roadmap-plan.md)
amends this decision: standalone mise owns portable runtime preparation and
Home Manager is removed from both builders. Nix owns system packages, not user
activation. Implementation and host deployment evidence are tracked separately.
Monorepo tool builds and project dev shells remain a separate track.

Spotlight retains a targeted nix-darwin activation step: CustomUserPreferences
replaces the entire symbolic-hotkey dictionary, losing unrelated user bindings
and key parameters. This preservation exception was verified and approved.

## Nix exceptions

| Tool | Reason |
|---|---|
| NixOS base userland, gcc and administrative tmux | System packages for OS administration; not Home Manager user packages |
| nixfmt, nil, nix-search-cli | Nix tooling |
| Login shell bash, man pages and terminfo | System prerequisites; project direnv remains native without nix-direnv |
| GnuPG on macOS | Conda GnuPG lacks its configured pinentry executable; protected-key signing fails after agent restart |
| All monorepo tools | Local-checkout Nix builds, never published binaries or npm packages |

Mermaid CLI, its Linux Chromium dependency and Neovim renderer are removed.
Gh-stack, Delta, Lazysql, google-java-format, Erlang and Elixir remain retired;
the migration harness retires gh-stack's store-backed extension link. Neovim
uses built-in diff rendering.

Btop and statix use conda across the fleet. Intel Atuin uses conda; ARM macOS
and Linux retain the registry backend. Registry tmux has complete platform
artifact locks. Fff is the executable, checksum-locked script from its tagged
GitHub source. Mac base tools use conda, including GNU sed to preserve unprefixed
GNU command behavior. Apple's `cc` supplies the Mac compiler.

`goimports` uses mise’s `go:` backend at 0.44.0. Native Go locks record a module
version, not platform archives or transitive build dependencies; Go’s module
checksum machinery verifies downloads. Supermicro retains system-level Nix
tmux 3.8 for administrative sessions independently of the user environment.

Python `pipx:yq` preserves the existing Python yq interface; it is not Go yq.
Platform-restricted declarations use mise's `os` selector; coverage checks require
artifacts only on those platforms. Current unsupported CLI exceptions remain
Nix-owned; formulae are limited to the ARM work host. Native Intel casks require
an explicit transfer from `/usr/local/Caskroom`, not receipt adoption.

## Configuration and lifecycle

This supersedes the package and user-configuration portions of ADRs 0002/0003.
The portable core and host overlay contain authored configuration. Standalone
bootstrap exposes canonical sources and Claude/Pi plugins. Mise-selected Node,
Python and uv prepare locked runtime dependencies and the Neovim provider.
No generated Nix fragment or Home Manager session bridge remains.

Whole-file templates cannot preserve app-written JSON/TOML/INI fields. Use native
mise merges for plain settings and npmrc; retain writers for map revocation,
managed hooks and skill-path removal. Mise 2026.11.2 is the minimum. Native
merges write in place; remaining writers use atomic replacement. Disable file
history/recovery capture because shared targets can contain credentials.
Applications retain runtime state and secrets, including Pi's package list.

`sys-update apply` orchestrates a system switch when available, portable
bootstrap, HOME-scoped skill synchronization and current-project environment
refresh. Failures stop later steps; `nixswitch` remains a pure system operation.
Native GUI transfers require reviewed migration. TPM and remote skills are
pinned mise repositories. Offline preparation preserves the last-good view when
sources are pending, but dirty or invalid sources fail. Native groups deploy
complete directories and retire only owned links.

PostgreSQL is a work-profile native tool. OmniWM uses a native cask and mise
LaunchAgent on ARM Macs; its legacy job/plist must be retired before the new
label is applied. Existing data and general Nix profiles are preserved.

RTK is one pinned mise tool across the fleet. Explicit `rtk:setup` uses upstream
Claude/Pi/Codex init, including Codex hooks. It compares existing RTK files against
disposable upstream output, rejects modifications and symlinks, and leaves custom
filters untrusted. No generated Nix RTK resources, patched store commands or
integration ownership ledger remain.

Global and host lockfiles are live-linked to the checkout. Native mise writes
through existing file symlinks and keeps dependency sidecars beside their resolved
targets. Platform artifacts cover ARM macOS, Intel macOS and x86-64 Linux. Native
npm shell-out pins top-level versions, not a locked transitive dependency graph.

Accept standard mise ownership: project overrides and other tracked configs
participate, preexisting packages remain unowned, and interrupted installation
can leave a package unowned. Preserve old ledgers instead of importing ownership.
Pruning is explicit. The one-off migration snapshots user data and uses native uninstall/install
commands; it does not fabricate mise receipts or become a package owner. See the
[fleet rollout runbook](../../mise-migration/README.md). See the [contract](../contracts/declarative-tooling.md)
and [cutover notes](../contracts/mise-cutover.md).

Deferred work is listed under [Next steps](../superpowers/plans/2026-11-03-mise-boundary-round-2-plan.md#next-steps).
