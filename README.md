# Dotfiles.nix

Nix owns system configuration and base packages; portable mise owns user tools
and configuration. Home Manager is not required.

## Where to edit your setup

- Shared tools and package selections: [mise/config.toml](mods/dotfiles/mise/config.toml).
- Hosts: `homes/<machine>/mise.toml`; each becomes global `config.local.toml`
  and includes shared roles from [mise/roles/](mods/dotfiles/mise/roles/).
  Dotfile entries stay in host files: mise rejects them in includes.
- App settings and managed-key fragments: [mise/apps/](mods/dotfiles/mise/apps/).
  Keep credentials in native app state or environment references.
- Skills: [skills.json](mods/agents/skills.json), with source pins in mise
  repository declarations. Shared instructions and authored links remain live.
- Runtime helpers and native plugins: [mise/runtime/](mods/dotfiles/mise/runtime/).
  The configuration writer is Deno with a vendored, locked `@std/toml`.
- Nix tooling, prerequisites and retained monorepo builds:
  [base-packages.nix](mods/base-packages.nix). NixOS base utilities:
  [system-packages.nix](mods/system-packages.nix).
- OS configuration and macOS preferences: `systems/`.
- Authored shell, Neovim and Karabiner configuration: `mods/dotfiles/`.

The system builders select one package set per host: 26.05 for Intel maclab,
unstable for ARM Macs and Linux. Local monorepo programs retain their Nix builds;
replacing project dev shells or splitting repositories is a separate migration.

## Bootstrap and apply

Use the monorepo checkout for system builds; its flake inputs reference sibling
projects. The userland bootstrap uses standalone mise >=2026.11.2 and needs no
Nix-generated fragment or Home Manager session variables.

```sh
cd pub/dotfiles-nix
./bootstrap.sh --only dotfiles,tools
mise -C "$HOME" run skills:sync
```

The machine defaults from the hostname map in `mods/dotfiles/shell/bash/lib/machine.sh`;
pass one explicitly (`./bootstrap.sh maclab`) for any directory under `homes/`.
Bootstrap refuses conflicting source/config links. It preserves matching links
and checks their ancestors on retries. Migrate an existing Home Manager installation with the
[fleet rollout runbook](mise-migration/README.md) instead.

`sys-update apply` validates the source and machine, switches the system when its
rebuild command exists, bootstraps userland, synchronizes skills in HOME, then
refreshes the caller's current-project mise environment and command cache.
Failures stop subsequent steps. It works without Nix; project overrides remain
active. `nixswitch` is only a system switch and never updates pins or bootstraps
userland. RTK initialization remains the explicit `sys-update rtk` operation.

```sh
mise -C "$HOME" bootstrap --only dotfiles
mise -C "$HOME" bootstrap dotfiles status
mise -C "$HOME" bootstrap packages status
sys-update apply
```

Package pruning and GUI ownership transfers are explicit operations, never
inferred from installed inventory. Bootstrap's normal package selection covers
Claude/Pi plugins; first GUI transfers go through the reviewed harness.
See the [ownership contract](docs/contracts/declarative-tooling.md) and
[cutover notes](docs/contracts/mise-cutover.md).

## Editor and desktop

Mise installs Neovim, LSP servers and DAP adapters. `nvim:prepare` creates the
locked pynvim environment outside the checkout; Neovim selects that interpreter,
disables Ruby and puts mise shims on PATH for GUI launches. nil remains a Nix
system tool. Mason is not a second installer; existing Mason data and plugin
locks are preserved during migration.

OmniWM is a native cask on the two ARM Mac profiles. Native mise LaunchAgents
preserve KeepAlive, RunAtLoad and log destinations under `dev.mise.omniwm`.
The pre-defaults hook refuses a remaining Home Manager agent or plist. Direct
launchd subcommands bypass bootstrap hooks: perform first ownership transfer
through the harness, which preserves and retires the old agent before applying
the new one. maclab and Supermicro do not enable OmniWM.

PostgreSQL is a work-profile mise tool, not an automatically started service.
Existing clusters are not relocated or upgraded by the package declaration.

## Updates and verification

```sh
sys-update list
sys-update check
sys-update pins nix-core
sys-update pins mise-tools
sys-update skills
```

Pin updates do not activate configuration. Inspect changed agent content before
applying. Tool pins and native lock sidecars cover the selected fleet platforms;
after manual pin edits run `scripts/lock-mise-fleet.sh`. Homebrew casks and Claude
plugins are deliberately unpinned; Neovim plugin updates rewrite `lazy-lock.json`.

`update-interactive` offers pull, pin updates, review, `sys-update apply`, then
native application updates. Cleanup is a separate opt-in and is skipped after
failed activation. Never clean generations needed by an active migration.

From the monorepo root:

```sh
make check FILTER=dotfiles-nix
make lint FILTER=dotfiles-nix
```

The project `mise.toml` also exposes `test:portable-runtime`,
`test:editor-lsp` and `test:postgres`. LSP acceptance without Nix reports nil as
a separate check; pass `--nil /path/to/nil` to `tests/editor-lsp.py` to test it.
GUI lifecycle fixtures do not certify a live desktop deployment. Follow the
[fleet rollout runbook](mise-migration/README.md) for backups, cask transfers,
verification and the user's wrap-up list.

For Google OAuth setup use [docs/gog.md](docs/gog.md). Authentication belongs in
native protected flows, not captured terminal or browser logs.

## homelab disk configuration 
1. setup the two 18tb drives using zfs
```bash
https://nixos.wiki/wiki/ZFS

fdisk -l



# format the drives
fdisk /dev/sda
fdisk /dev/sdb
# p - print
# g - create a new GPT partition table
# w - write the changes
# n - new partition
# --- use defaults for the entire disk
# w - write the changes


# create the zpool with compression on 
# enable acltype=posixacl to allow for linux style ACLs
# enable xattr=sa to store extended attributes in the inode
# ashift=12 is the default for 4k sector drives
zpool create -O compression=on -O mountpoint=none -O xattr=sa -O acltype=posixacl -o ashift=12 storagepool mirror /dev/sda1 /dev/sdb1

zfs create -o mountpoint=legacy storagepool/storage
sudo zfs set acltype=posixacl storagepool/storage
sudo zfs set aclinherit=discard storagepool/storage
sudo zfs set aclmode=discard storagepool/storage
sudo zfs get acltype,aclinherit,aclmode storagepool/storage
sudo zfs set aclmode=discard storagepool/storage
mount -t zfs storagepool/storage /media/storage
```
