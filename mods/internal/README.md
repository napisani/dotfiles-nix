# Tooling implementation

For normal configuration edits, start with the [editing guide](../../README.md#where-to-edit-your-setup).
Shared selections belong in public `mods/` modules; host differences belong in `homes/`.
Do not select hosts, roles, packages or models here.

- `agents/`: option validation and independent native agent adapters.
- `npm.nix`, `uv.nix`, `model-runtimes.nix`: native execution from declared options.
- `global-tools.nix`: shared activation/CLI command registration and ordering.
- `scripts/`: CLI, config writers and shared reconciliation helpers.
- Each domain's `scripts/` directory contains its native scripts and adjacent tests.

`native-scripts.nix` copies runtime code into the installed generation. Preserve
relative imports between domain scripts and `scripts/lib/`; never execute
installer code from a mutable checkout path. Authored agent/shell/editor assets
remain in `mods/dotfiles/`, including their intentionally live links.

Run `nix flake check` from the dotfiles flake for the subprocess contracts.
Tests use temporary homes and fake installers, not live package/model operations.
