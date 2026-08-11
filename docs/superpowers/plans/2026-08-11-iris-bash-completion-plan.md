# Iris Bash Completion Implementation Plan

**Goal:** Install and configure Iris declaratively on every Home Manager host for Bash completion and ghost text, while retaining Atuin's `Ctrl-R` history UI.

**Architecture:** Pin Iris as a flake input. A focused `mods/iris.nix` module owns its package and TOML links; `homes/profiles/common.nix` imports it for every host. The first sourced Bash dotfile starts Iris and makes its child resolve to the active Nix Bash instead of macOS `/bin/bash`.

---

### Task 1: Add the pinned Iris package

**Files:**
- Modify: `flake.nix`
- Modify: `flake.lock`
- Create: `mods/iris.nix`
- Modify: `homes/profiles/common.nix`

- [x] Add `github:versenilvis/iris/main` as the `iris` flake input and lock its dependency graph.
- [x] Install `inputs.iris.packages.${pkgs.stdenv.hostPlatform.system}.default` through the focused Iris module.
- [x] Import the module from the shared profile so every host receives it.

### Task 2: Integrate Bash without taking Atuin's history key

**Files:**
- Create: `mods/dotfiles/.bashrc.d/0001_iris.bashrc`
- Revert: `mods/shell.nix`

- [x] Keep `mods/shell.nix` free of Iris-specific package, config, and initialization declarations.
- [x] Start Iris from the first sourced interactive `.bashrc.d` file, before NVM.
- [x] Put `dirname "$BASH"` first in `PATH` before Iris starts, so its literal `bash` child command resolves to the active Nix Bash rather than macOS Bash 3.2.
- [x] Keep the existing Atuin module and settings intact so its generated Bash integration owns `Ctrl-R`.

### Task 3: Add declarative Iris configuration

**Files:**
- Create: `mods/dotfiles/iris/config.toml`
- Create: `mods/dotfiles/iris/theme.toml`
- Modify: `mods/iris.nix`

- [x] Set Iris to Bash spec mode with ghost text and no Atuin history source.
- [x] Rebind Iris's mode switch to `Ctrl-G`, leaving `Ctrl-R` to the child Bash/Atuin binding.
- [x] Disable Iris's update checks and automatic updates; flake updates control versions.
- [x] Use the upstream Tokyo Night palette.
- [x] Link both TOML files to `~/.config/iris/` through out-of-store symlinks.

### Task 4: Validate

- [x] Reproduce the original failure with macOS `/bin/bash` sourcing the generated Home Manager `.bashrc`.
- [x] Verify the Iris hook resolves `bash` to the active `$BASH` executable.
- [x] Validate the hook with `bash -n` and format changed Nix with `nixfmt`.
- [x] Run `nix flake check`.
- [x] Inspect the final diff.
