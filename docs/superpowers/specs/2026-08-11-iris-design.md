# Iris Bash completion design

## Goal

Install [Iris](https://github.com/versenilvis/iris) declaratively on every configured host while preserving Atuin as the sole history UI on `Ctrl-R`. Iris provides inline typeahead, command/file completion, and ghost text; Atuin keeps history search and synchronization.

## Scope

- All Home Manager hosts: three Darwin configurations and the Supermicro NixOS configuration.
- Bash only, which is the shell managed by `mods/shell.nix`.
- No AI suggestions, imperative Iris setup, self-updates, or changes to Atuin's existing configuration.

## Architecture

### Package source

Add this flake input to `flake.nix`:

```nix
iris.url = "github:versenilvis/iris/main";
```

The repository's `flake.lock` resolves this moving branch to a fixed revision. A dedicated `mods/iris.nix` module installs the upstream default package through `home.packages` using the current host platform:

```nix
inputs.iris.packages.${pkgs.stdenv.hostPlatform.system}.default
```

`homes/profiles/common.nix` imports the module for every host. `lib/builders.nix` already passes `inputs` to every Home Manager module via `extraSpecialArgs`, so no builder change is needed.

### Bash ordering

Keep `programs.atuin` and `mods/shell.nix` unchanged. The Iris hook lives in the first sourced shell file, `mods/dotfiles/.bashrc.d/0001_iris.bashrc`, so it starts before NVM and the other shell setup.

Iris's Bash adapter starts its child shell by resolving literal `bash` through `PATH`. The hook puts the directory containing the active `$BASH` binary first in `PATH` before it evaluates `iris init bash`. Therefore its child re-enters the Nix-managed Bash instead of macOS's legacy `/bin/bash` 3.2, which cannot parse the generated Home Manager Bash configuration.

The hook is guarded by Bash's interactive flag. Iris replaces the initial interactive shell with its wrapper; its Nix Bash child sees `IRIS_PID`, does not start another wrapper, then completes the remaining shell initialization. This leaves Atuin's `Ctrl-R` binding available in the child shell and prevents NVM initialization from running twice.

## Iris configuration

Add these live-editable source files:

- `mods/dotfiles/iris/config.toml`
- `mods/dotfiles/iris/theme.toml`

Expose them from `mods/iris.nix` with an out-of-store symlink helper as:

- `~/.config/iris/config.toml`
- `~/.config/iris/theme.toml`

The config has the following behavioral contract:

- `core.shell = "bash"` and `core.mode = "spec"`: Iris starts in command/file completion mode.
- `core.atuin-history = 0`: Iris does not read or render Atuin history.
- Ghost text, modern UI, Nerd Font icons, and the existing sensible menu size defaults are enabled.
- Iris's mode switch moves from its default `Ctrl-R` to `Ctrl-G`; `Shift-Tab` toggles its menu and `Tab` accepts a suggestion.
- Iris's update check and auto-update stay disabled. The flake lock, updated with `nix flake update iris`, is the only package-update mechanism.
- `theme.toml` uses Iris's upstream Tokyo Night palette to match the managed Ghostty `tokyonight` theme.

With this configuration, Iris has no binding for `Ctrl-R`, so it forwards that key to the child Bash where Atuin's existing binding opens its history interface.

## Operational boundaries

Do not run `iris setup`, `iris update`, or `iris uninstall`; those commands copy binaries or edit shell files outside Nix ownership. The package and configuration links are managed by `mods/iris.nix`; the init hook is a symlinked `.bashrc.d` dotfile.

Removing the flake input, Iris module import, hook, and file links fully removes the managed setup on the next normal rebuild.

## Verification

Before activation:

1. Format changed Nix files with `nixfmt`.
2. Run the repository's Nix flake check and applicable machine dry-run build checks. Do not run a switch.

After the user's normal switch, open a new Bash session and verify:

1. `command -v iris` resolves to the Nix-managed binary.
2. Typing a partial command shows Iris completion/ghost text, and `Tab` accepts a suggestion.
3. `Ctrl-R` opens Atuin's history UI.
4. `iris config show` reflects the linked configuration.
5. `command -v bash` resolves to the same executable as `$BASH` after the Iris hook runs.

A package evaluation/build incompatibility is caught by the pre-activation Nix checks. If a configuration change is malformed, Iris can be diagnosed without enabling debug logging (which would record typed input); correct the linked TOML and reopen the shell.
