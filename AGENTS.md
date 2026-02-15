# Agent Guidelines for Nix/Home-Manager Dotfiles

## Overview

This repository is a **Nix flake** for configuring and managing multiple systems (macOS via nix-darwin and NixOS). It contains:
1. **Root project**: Nix flake for system/package configuration and dotfile management
2. **Sub-project: Karabiner** - Keyboard configuration at `./mods/dotfiles/karabiner`
3. **Sub-project: Neovim** - Editor configuration at `./mods/dotfiles/nvim`

Each sub-project has its own AGENTS.md, conventions, and build processes. Read the relevant sub-project AGENTS.md before making changes.

---

## Machine Inventory

| Hostname | Platform | Architecture | System Type | Build Command (dry-run) |
|---|---|---|---|---|
| nicks-mbp | macOS | aarch64-darwin | Personal MacBook Pro | `nix build .#darwinConfigurations.nicks-mbp.system --dry-run` |
| nicks-axion-ray-mbp | macOS | aarch64-darwin | Work MacBook (Axion Ray) | `nix build .#darwinConfigurations.nicks-axion-ray-mbp.system --dry-run` |
| maclab | macOS | x86_64-darwin | Mac lab machine | `nix build .#darwinConfigurations.maclab.system --dry-run` |
| supermicro | NixOS | x86_64-linux | Homelab server | `nix build .#nixosConfigurations.supermicro.config.system.build.toplevel --dry-run` |

**IMPORTANT**: Do NOT run actual build/switch commands (`darwin-rebuild switch`, `nixos-rebuild switch`) - only validate with `--dry-run`.

---

## Root Project: Nix/Home-Manager Configuration

### Build & Test Commands
- **Validate**: Use the build command from machine inventory with `--dry-run`
- **Format Nix files**: `nix fmt <file>.nix`
- **Lint Nix files**: `statix check .`
- **Check flake metadata**: `nix flake metadata`

### Code Style & Conventions
- **Language**: Nix expression language
- **Formatting**: `nixfmt-classic`, 2-space indentation
- **File organization**: `mods/` for shared modules, `homes/` for per-machine user configs, `systems/` for system configs, `lib/` for builder functions
- **Imports**: Relative paths (e.g., `../../mods/neovim.nix`)
- **Package preferences**: Prefer `pkgs-unstable` for most packages
- **Naming**: kebab-case for files (e.g., `base-packages.nix`)
- **Comments**: Inline comments for non-obvious configurations or workarounds

### Architecture Patterns

#### Builder Pattern
`lib/builders.nix` provides `mkDarwinSystem` and `mkNixOSSystem` that automatically wire up:
- Base system profiles (e.g., `darwin-base.nix`)
- Home-manager with `extraSpecialArgs` (pkgs-unstable, custom flake inputs)
- Profile layering: `common.nix` + platform profile + per-machine home module

#### Profile Layering
**System level**: `darwin-base.nix` (all Macs) -> `darwin-{personal,work,maclab}.nix` (per-machine)

**Home level**: `common.nix` (all machines) -> `darwin.nix` (all Macs) -> `home-<machine>.nix` (per-machine)

#### Symlink Strategy (User Preference)
Dotfiles are symlinked from `mods/dotfiles/` using `mkOutOfStoreSymlink` for live editability. This is intentional -- edits to dotfiles take effect immediately without Nix rebuild. The `shell.nix` module uses a `mkSym` helper to create these symlinks concisely.

When Nix rebuild IS needed:
- Adding/removing packages
- Changing module imports
- Modifying Nix expressions

When Nix rebuild is NOT needed:
- Editing any dotfile in `mods/dotfiles/` (nvim config, tmux.conf, etc.)
- Editing Karabiner TS sources (just rebuild with `deno task build`)

#### Language Modules
Language tooling in `mods/languages/` aggregated by `all.nix`. Imported by both `base-packages.nix` (shell use) and `neovim.nix` (extraPackages). Languages: JavaScript/TypeScript, Python, Go, Java, C++, Lua, Nix, Bash, Elixir.

#### Activation Hooks
`mods/uvx.nix` and `mods/npmx.nix` use home-manager activation hooks to install tools via `uv tool install` and `npm install -g` for packages not easily packaged in Nix.

#### Custom Flake Inputs
Several of the user's own projects are consumed as flake inputs: `procmux`, `proctmux`, `secret_inject`, `animal_rescue`, `scrollbacktamer`, `rift`.

### Common Gotchas
- The `nil` flake input was recently removed -- the Nix LSP comes from `pkgs-unstable.nil` in `languages/nix.nix`
- `home-supermicro.nix` has its own independent module imports (doesn't layer through `common.nix` the same way as Darwin machines)
- Machine differentiation uses `MACHINE_NAME` session variable
- Several inputs could benefit from `nixpkgs.follows` but this hasn't been added yet to avoid potential build breakage

---

## Sub-Project: Karabiner Keyboard Configuration

**Location**: `./mods/dotfiles/karabiner`

**See also**: Karabiner's own README.md for symlink chain and troubleshooting

### Build & Test Commands
```bash
# Build (from karabiner/ directory)
deno task build

# Reload
karabiner-reload.sh

# Full restart if reload doesn't work
osascript -e 'quit app "Karabiner-Elements"' && sleep 1 && open -a 'Karabiner-Elements'
```

### Code Style & Conventions
- **Language**: TypeScript with Deno runtime
- **Formatting**: `deno fmt`
- **Naming**: kebab-case for files (e.g., `cap-modifier.ts`, `window-layer.ts`)
- **Exports**: Rule arrays (e.g., `export const layerRules = [...]`)
- **Imports**: Import karabiner.ts library; always include `../polyfill.ts` first in index.ts

### Architecture Patterns
- **Generated config**: TypeScript sources generate `karabiner.json` one level up from `karabiner/`
- **Symlink managed by Nix**: `~/.config/karabiner/karabiner.json` -> generated file
- **Edit-generate-reload workflow**: Modify TS -> `deno task build` -> reload (no Nix rebuild)

### Active Modules (in rule priority order)
1. `cap-modifier.ts` -- Caps Lock as variable-based layer (hjkl arrows, Ctrl+key, screenshots)
2. `modifier-swap.ts` -- Per-app Cmd/Ctrl/Fn swapping (terminal vs GUI apps)
3. `layers.ts` -- Simlayers: `a`=delimiters, `d`=arrows, `l`=symbols, `n`=numbers, `s`=ctrl
4. `window-layer.ts` -- Tab as dual-role window manager key (rift-cli tiling)
5. Inline escape->grave rule in `index.ts`

### Support Files
- `polyfill.ts` -- CJS require() shim for karabiner.ts npm package in Deno
- `leader-utils.ts` -- `exitLeader()` helper (used by cap-modifier.ts)

### Adding New Rules
1. Create/edit a file in `src/` (kebab-case)
2. Export rules array: `export const myRules = [rule(...).manipulators([...])]`
3. Import in `src/index.ts`
4. Add to `writeToProfile()` array
5. Run `deno task build && karabiner-reload.sh`

### Important Notes
- **Output**: `~/.config/home-manager/mods/dotfiles/karabiner.json` (NOT inside karabiner/ dir)
- DO NOT manually edit `~/.config/karabiner/karabiner.json` -- breaks symlink
- Commit both TypeScript sources AND generated JSON
- Broken symlink: run `darwin-rebuild switch --flake .#<hostname>` to restore

---

## Sub-Project: Neovim Configuration

**Location**: `./mods/dotfiles/nvim`

**See also**: `./mods/dotfiles/nvim/AGENTS.md` for detailed Neovim-specific guidelines

### Build & Test Commands
```bash
# Test module loading
nvim --headless -c "lua require('user.plugins.category.name')" -c "qa"

# Test keymap discovery
nvim --headless -c "lua local p = require('user.whichkey.plugins'); print(vim.inspect(p.get_all_plugin_keymaps()))" -c "qa"

# Full health check
nvim --headless -c "checkhealth" -c "qa"
```

### Key Architecture Points (see nvim/AGENTS.md for full details)
- **Plugin registry** (`plugin_registry.lua`): single source of truth for module loading and keymap discovery
- **Dual LSP architecture**: `lsp/` dir for native `vim.lsp.config()` server configs, `lua/user/lsp/` for orchestration
- **Snacks.nvim** replaces Telescope as the picker framework
- **Which-key v3**: keymaps aggregated from multiple sources in `whichkey/whichkey.lua`
- **EFM LSP**: format-on-save with auto-detection of formatters per project

---

## General Guidelines

### When Working on This Repository
1. **Identify the scope**: Determine if you're working on Nix configs, Karabiner, or Neovim
2. **Follow sub-project conventions**: Each has different languages, tools, and patterns
3. **Read the sub-project AGENTS.md**: Neovim and Karabiner have their own detailed guides
4. **Test appropriately**: Use the correct build/test commands for each sub-project
5. **Rebuild when needed**:
   - Nix changes -> validate with dry-run build
   - Karabiner changes -> `deno task build` + reload
   - Neovim changes -> no rebuild needed (live reloadable via symlink)
