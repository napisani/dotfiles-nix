# Iris Bash Completion Implementation Plan

**Goal:** Install and configure Iris declaratively on every Home Manager host for Bash completion and ghost text, while retaining Atuin's `Ctrl-R` history UI.

**Architecture:** Pin Iris as a flake input, install its upstream default package from the shared shell module, and initialize it after Atuin through `programs.bash.initExtra`. Keep the Iris TOML files under `mods/dotfiles/iris/` and link them with the shell module's existing out-of-store symlink helper.

---

### Task 1: Add the pinned Iris package

**Files:**
- Modify: `flake.nix`
- Modify: `flake.lock`
- Modify: `mods/shell.nix`

- [x] Add `github:versenilvis/iris/main` as the `iris` flake input.
- [x] Refresh only the `iris` lock node.
- [x] Add `inputs` and `lib` to `mods/shell.nix` arguments.
- [x] Install `inputs.iris.packages.${pkgs.stdenv.hostPlatform.system}.default` through `home.packages`.

### Task 2: Integrate Bash without taking Atuin's history key

**Files:**
- Modify: `mods/shell.nix`

- [x] Add `eval "$(iris init bash)"` to `programs.bash.initExtra` with `lib.mkAfter`.
- [x] Keep the existing Atuin module and settings intact so its generated Bash integration still owns `Ctrl-R`.

### Task 3: Add declarative Iris configuration

**Files:**
- Create: `mods/dotfiles/iris/config.toml`
- Create: `mods/dotfiles/iris/theme.toml`
- Modify: `mods/shell.nix`

- [x] Set Iris to Bash spec mode with ghost text and no Atuin history source.
- [x] Rebind Iris's mode switch to `Ctrl-G`, leaving `Ctrl-R` to the child Bash/Atuin binding.
- [x] Disable Iris's update checks and automatic updates; flake updates control versions.
- [x] Use the upstream Tokyo Night palette.
- [x] Link both TOML files to `~/.config/iris/` through `mkForcedSym`.

### Task 4: Validate

**Files:**
- `flake.nix`
- `flake.lock`
- `mods/shell.nix`
- `mods/dotfiles/iris/config.toml`
- `mods/dotfiles/iris/theme.toml`

- [x] Format the changed Nix files with `nixfmt`.
- [x] Run `nix flake check`.
- [x] Run dry-run builds for the active Darwin configurations and NixOS host; do not switch.
- [x] Inspect the final diff.
