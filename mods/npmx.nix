{
  config,
  lib,
  pkgs-unstable,
  machineRoles ? [ ],
  ...
}:

let
  # List npm packages to install globally into $HOME/.local.
  # Examples: [ "eslint" "@biomejs/biome" "typescript@5" ]
  #
  # ACP CLIs for agentic.nvim: bins land in ~/.local/bin (e.g. claude-agent-acp, codex-acp).
  # Neovim from Dock/Finder often lacks ~/.local/bin on PATH; mods/dotfiles/nvim/lua/user/plugins/ai/agentic.lua
  # sets explicit command paths so :checkhealth agentic and spawning still work.
  #
  # OpenCode community skills are declared in mods/agents/skills.nix's catalog.
  npmxTools = [
    "@ellery/terminal-mcp@latest"
    "@napisani/scute@latest"
    "@earendil-works/pi-coding-agent"
    "@agentclientprotocol/claude-agent-acp"
    "@zed-industries/codex-acp"
    "@playwright/cli"
  ];

  removedNpmPackages = [
    "@mariozechner/pi-coding-agent"
    "pi-skillful"
    # Duplicated `rtk init -g --opencode`'s own generated plugin
    # (~/.config/opencode/plugins/rtk.ts) — keep just the one rtk source.
    "openrtk"
    "@agentmemory/mcp"
    "@agentmemory/agentmemory"
  ];

  # Pi packages are declared and diff-pruned in mods/agents/pi.nix
  # (installPiPackages, via managed-config-lib.nix's mkPiPackageInstall) —
  # not here. That mechanism tracks Nix-managed state and removes anything
  # undeclared automatically, replacing this file's old manually-maintained
  # removedPiPackages list.

  npm = "${pkgs-unstable.nodejs}/bin/npm";
  nodeBin = "${pkgs-unstable.nodejs}/bin";
  gitBin = "${pkgs-unstable.git}/bin";
  npmPrefix = "${config.home.homeDirectory}/.local";

  # ~/.npmrc used to be declared via home.file (mods/shell.nix), which Home
  # Manager links as a read-only symlink into /nix/store. That's fine as
  # long as nothing ever tries to write to it again later — but this module
  # used to also run `npm config set prefix ... --location=user`, which
  # always failed EACCES against that immutable target (npm's own error
  # message misleadingly blamed a root-owned ~/.npm cache instead). Writing
  # ~/.npmrc imperatively here, as a real file, keeps it colocated with the
  # rest of this module's npm setup and keeps any future imperative
  # `npm config` write actually usable. See WORKAROUNDS.md "npm config set
  # prefix vs. immutable ~/.npmrc".
  npmrcContent =
    "prefix=${npmPrefix}\n"
    + lib.optionalString (builtins.elem "loancrate" machineRoles) "//registry.npmjs.org/:_authToken=\${NODE_AUTH_TOKEN}\n";
in
{
  home.packages = [
    pkgs-unstable.nodejs
    pkgs-unstable.git
  ];

  home.sessionVariables = {
    NPM_CONFIG_PREFIX = npmPrefix;
  };

  # Writes ~/.npmrc directly (not via home.file) so it's a plain, writable
  # file rather than a Home Manager-managed symlink into the read-only Nix
  # store — see the npmrcContent comment above.
  home.activation.writeNpmrc = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        cat > "${config.home.homeDirectory}/.npmrc" <<'NPMRC_EOF'
    ${npmrcContent}NPMRC_EOF
  '';

  home.activation.installNpmxTools =
    lib.hm.dag.entryAfter
      [
        "writeBoundary"
        "agentsWarnReportInit"
        "writeNpmrc"
      ]
      ''
        export NPM_CONFIG_PREFIX="${npmPrefix}"
        mkdir -p "$NPM_CONFIG_PREFIX/bin" "$NPM_CONFIG_PREFIX/lib"
        export DISABLE_TELEMETRY=1
        failed=0

        # Home Manager activation runs with a minimal PATH; ensure npm scripts can
        # find `node`.
        export PATH="${gitBin}:${nodeBin}:$NPM_CONFIG_PREFIX/bin:$PATH"

        for package in ${builtins.concatStringsSep " " removedNpmPackages}; do
          if ${npm} list -g --depth=0 "$package" >/dev/null 2>&1; then
            if ! ${npm} uninstall -g "$package"; then
              echo "installNpmxTools: ERROR: npm uninstall -g failed for removed package: $package" >&2
              failed=$((failed + 1))
            fi
          fi
        done

        for tool in ${builtins.concatStringsSep " " npmxTools}; do
          if ! ${npm} install -g --no-fund --no-audit "$tool"; then
            echo "installNpmxTools: ERROR: npm install -g failed for: $tool" >&2
            failed=$((failed + 1))
          fi
        done

        if [ "$failed" -gt 0 ]; then
          echo "installNpmxTools: $failed install step(s) failed (Neovim agentic ACP CLIs need a successful install). Re-run with network and check the errors above." >&2
          printf '%s\n' "npmx: $failed npm install step(s) failed" >> "''${AGENTS_WARN_FILE:-/dev/null}"
        fi

        # Some npm packages ship their bin entrypoints without the executable bit.
        # Ensure anything linked into ~/.local/bin is runnable.
        chmod -R u+rx "$NPM_CONFIG_PREFIX/bin" 2>/dev/null || true
      '';
}
