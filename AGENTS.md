# Agent Guidelines for Nix/Home-Manager Dotfiles

## Build & Test Commands
- **Build**: `nixswitchup` 
- **Format Nix files**: `nix fmt <file>.nix`
- **Lint Nix files**: `statix check .`
- **No test framework**: This is a configuration repository; validation happens via successful builds

## Code Style & Conventions
- **Language**: Nix expression language for system/package configuration
- **Formatting**: Use `nixfmt-classic` for consistent formatting; 2-space indentation
- **File organization**: Modular structure - `mods/` for modules, `homes/` for user configs, `systems/` for system configs
- **Imports**: Use relative paths (e.g., `../mods/neovim.nix`); organize by category (language, tool, system)
- **Package preferences**: Prefer `pkgs-unstable` for most packages to get latest versions
- **Naming**: Use kebab-case for files (e.g., `base-packages.nix`), descriptive module names
- **Configuration**: Symlink dotfiles from `mods/dotfiles/` using `mkOutOfStoreSymlink` for editability
- **Comments**: Add inline comments for non-obvious configurations or workarounds (see git.nix examples)

## Architecture Patterns
- **Flake-based**: All configurations use flake.nix with inputs/outputs structure
- **Platform separation**: Darwin (macOS) vs NixOS (Linux) configs are split; share common modules
- **Home-Manager integration**: User environment managed via home-manager, not imperative installs
- **Language modules**: Language tooling organized in `mods/languages/`, imported via `all.nix`



