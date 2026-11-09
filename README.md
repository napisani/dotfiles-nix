# Dotfiles.nix

Git declares the setup, Nix configures the machine, and portable mise configures
the user environment. Home Manager is not a deployment layer.

| Owner | Resources |
|---|---|
| Nix / nix-darwin | OS settings, services, fonts, prerequisites, local monorepo builds such as Scute/proctmux, and Mac GPG |
| Mise | Language runtimes, most CLIs, Neovim/LSPs, dotfiles, agent configuration, skills and plugins |
| Applications | Credentials, databases, histories and settings outside explicitly managed fields |

The lifecycle is **edit or update pins → review and commit → pull on each host →
apply → restart affected applications**. Updating one host does not deploy to
other hosts. Supermicro's Kubernetes GitOps loop separately follows monorepo
main; review that impact when merging changes to its desired state.

Each host's `~/.config/mise` links into its own monorepo checkout. Many deployed
files are symlinks too: editing the linked checkout or pulling changes can affect
shell/editor configuration immediately, before an apply. Make persistent changes
in the repository; application-owned settings and credentials stay in the app.

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
  The configuration writer is Python in the locked uv environment.
- Nix tooling, prerequisites and retained monorepo builds:
  [base-packages.nix](mods/base-packages.nix). NixOS base utilities:
  [system-packages.nix](mods/system-packages.nix).
- OS configuration and macOS preferences: `systems/`.
- Authored shell, Neovim and Karabiner configuration: `mods/dotfiles/`.

The system builders select one package set per host: 26.05 for Intel maclab,
unstable for ARM Macs and Linux. Local monorepo programs retain their Nix builds;
replacing project dev shells or splitting repositories is a separate migration.

## Bootstrap and apply

### Apply a reviewed checkout on one host

Run the shell helpers from an interactive Bash with the login profile loaded.
They use the checkout selected by `DOTFILES_DIR`, not the current directory;
`printf '%s\n' "$DOTFILES_DIR"` shows the active dotfiles source.

For a host using `~/code/monorepo`, resolve or commit existing local work before
pulling, then run:

```sh
cd ~/code/monorepo
git status
git pull --ff-only
sys-update apply
```

The pull follows that checkout's current upstream branch. **`sys-update apply`
does not pull Git changes or select newer package versions.** It applies the
current checkout in this order:

1. Validate the source and host, then switch Nix when a rebuild command exists.
2. Run standalone bootstrap: link configuration, install declared tools and
   reconcile Claude/Pi packages. Tool hooks prepare editor providers and managed
   application settings.
3. Fetch pinned skill sources and prepare/deploy skills in HOME.
4. Refresh the caller's current-project mise environment and command cache.

Failures stop subsequent apply steps. Running editors and agents are not
restarted; reload or restart them when their configuration or packages change.
Repeat the pull/apply on each host that should receive the change.

`nixswitch` switches **only Nix**: it does not pull, update pins, bootstrap mise
or synchronize skills. `sys-update rtk` is separate, explicit RTK initialization,
not part of ordinary apply.

### Apply userland without rebuilding Nix

Use the monorepo checkout for system builds; its flake inputs reference sibling
projects. Portable userland needs standalone mise >=2026.11.2, not a
Nix-generated fragment or Home Manager session variables.

For tool, agent-package and configuration changes that do not alter Nix:

```sh
~/code/monorepo/pub/dotfiles-nix/bootstrap.sh
mise -C "$HOME" run skills:sync
```

Bootstrap's default phases are `dotfiles,tools,packages`; its package managers
are restricted to Claude/Pi, so this does not perform GUI ownership transfers or
upgrade GUI applications. `--only dotfiles,tools` omits agent-package installation.
The host defaults from `mods/dotfiles/shell/bash/lib/machine.sh`; pass one
explicitly, such as `./bootstrap.sh maclab`, for a directory under `homes/`.

Bootstrap refuses conflicting source/config links, preserves matching links and
checks their ancestors on retries. For an initial Home Manager ownership
transfer, use the [fleet rollout runbook](mise-migration/README.md), not an
ordinary bootstrap/apply.

For dotfile and managed agent-settings edits without tool installation:

```sh
mise -C "$HOME" bootstrap --only dotfiles
mise -C "$HOME" run apps:configure
```

The first command applies native links, copies and merges; `apps:configure`
reconciles managed agent fields and prepares providers/skills. Use `-C "$HOME"`
for host defaults so a project's mise configuration does not change the scope.
Inspect deployment state with:

```sh
mise -C "$HOME" bootstrap dotfiles status
mise -C "$HOME" bootstrap packages status
```

Shared settings preserve application-owned siblings, but explicitly managed maps
such as MCP declarations are replaced from their authored inputs. See the
[ownership contract](docs/contracts/declarative-tooling.md) and
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

### Upgrade pinned tools and dependencies

**Update pins first; install/apply them separately.** The pin updater changes
recorded versions and locks and verifies the result; it does not activate the
system or upgrade the declared host tools. For example:

```sh
sys-update list                       # Show domains and item names
sys-update check                      # Read-only; exit 1 means updates are available
sys-update pins mise-tools node       # Update one recorded tool version
git -C ~/code/monorepo diff            # Review the whole checkout's changes
sys-update apply                     # Install and activate the declared versions
```

Commit the reviewed version/lock changes and distribute them through Git so
other hosts can pull/apply the same declarations. Check and pins default to
project `dotfiles-nix`; `sys-update help` lists filtering and approval options.

| Command | What its pins control |
|---|---|
| `sys-update pins mise-tools` | Node/Python/Go runtimes, Neovim, non-npm CLIs and the Claude/Codex executables |
| `sys-update pins npm-tools` | The Pi CLI and npm-based CLIs/LSPs |
| `sys-update pins python-tools` | Isolated `pipx:` Python tools, not the Python runtime |
| `sys-update pins pi` | Pi extension packages, not the Pi CLI |
| `sys-update pins mise-repos` | Skill repositories, TPM and other repository sources |
| `sys-update pins nix-core` | Nix foundation inputs such as nixpkgs and nix-darwin |

Name an item after the domain to limit an update, as in the Node example. Major
and held upgrades are not silently accepted; review the updater's explanation
before explicitly allowing them. Review changed skills and Pi extensions before
applying: they supply agent instructions and executable code.

The shell helpers target the active linked checkout even if invoked from another
worktree. To author updates away from a live checkout, use the monorepo command
from the development worktree's root instead:

```sh
make deps-update PROJECT=dotfiles-nix DOMAIN=mise-tools ITEMS=node
```

Then review, commit and distribute the change before applying it on hosts.
Include all files the updater changes, including regenerated fleet locks,
`.mise/locks/` sidecars and derived skill locks. After manually editing tool pins,
run `pub/dotfiles-nix/scripts/lock-mise-fleet.sh` from the monorepo root.

### Native application and plugin updates

These commands update installed resources immediately, rather than selecting
new CLI/runtime pins:

| Command | Effect |
|---|---|
| `sys-update brew` | Upgrade declared formulae and mise-owned casks |
| `sys-update claude` | Refresh declared Claude plugins, not the Claude CLI |
| `sys-update nvim` | Update Neovim plugins and rewrite `mods/dotfiles/nvim/lazy-lock.json`; commit that lock change |
| `sys-update skills` | Fetch and deploy the currently pinned skill revisions; use `pins mise-repos` to select newer revisions first |
| `sys-update rtk` | Explicit guarded RTK integration initialization |

`sys-update tools` groups **brew, nvim and claude only**; it is not an upgrade
of all pinned tools. Prefer the pin workflow over ad-hoc global npm updates,
`mise upgrade` or bare `pi update` for configuration-managed tools. Homebrew
casks and Claude plugins are deliberately unpinned.

Mise itself is a standalone installation. Bootstrap installs it when absent;
upgrade the binary separately without updating repository-managed adapters:

```sh
mise self-update --no-plugins
```

Normal apply/update does not take over externally owned GUI applications.
Docker Desktop on nicks-mbp is a Homebrew-owned compatibility exception; update
it separately with `brew upgrade --cask docker-desktop`. Maclab's Docker Desktop
installation remains application/operator-managed. First ownership transfers
require the reviewed migration procedure, not force/adoption flags.

### Guided updates, cleanup and rollback

Run `update-interactive` for pull, pin checks/updates, review, `sys-update apply`
and native application updates. Every step asks yes/no and defaults to no.

Cleanup is a separate opt-in, skipped after failed activation. `nixclean` deletes
old Nix rollback generations and unused store paths; it is not required to apply
updates. Package pruning is also explicit, never a blanket cleanup inferred
from inventory. Never clean generations needed by an active migration.

Nix system rollback does not undo mise installations, GUI application upgrades
or application-data changes. Ordinary apply does not create a migration backup;
make independent backups before changes that need a data rollback path.

### Verification

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
