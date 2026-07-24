{
  config,
  lib,
  pkgs-unstable,
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
  # OpenCode community skills are declared in mods/opencode.nix (`opencodeCommunitySkillSources`).
  npmxTools = [
    "@ellery/terminal-mcp@latest"
    "@napisani/scute@latest"
    "skills@latest"
    "@earendil-works/pi-coding-agent"
    "@agentclientprotocol/claude-agent-acp"
    "@zed-industries/codex-acp"
    "@playwright/cli"
    # agentmemory: MCP server binary (mods/agents/{claude,codex,pi}.nix each
    # reference ~/.local/bin/agentmemory-mcp directly, no npx spawn) + the
    # `agentmemory` CLI for running the full persistent server/viewer.
    "@agentmemory/mcp"
    "@agentmemory/agentmemory"
  ];

  removedNpmPackages = [
    "@mariozechner/pi-coding-agent"
    "pi-skillful"
    # Duplicated `rtk init -g --opencode`'s own generated plugin
    # (~/.config/opencode/plugins/rtk.ts) — keep just the one rtk source.
    "openrtk"
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
in
{
  home.packages = [
    pkgs-unstable.nodejs
    pkgs-unstable.git
  ];

  home.sessionVariables = {
    NPM_CONFIG_PREFIX = npmPrefix;
  };

  home.activation.installNpmxTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export NPM_CONFIG_PREFIX="${npmPrefix}"
    mkdir -p "$NPM_CONFIG_PREFIX/bin" "$NPM_CONFIG_PREFIX/lib"
    export DISABLE_TELEMETRY=1
    failed=0

    # Persist npm's global prefix for tools such as Pi that shell out to
    # `npm install -g` during normal interactive use.
    if ! ${npm} config set prefix "$NPM_CONFIG_PREFIX" --location=user; then
      echo "installNpmxTools: ERROR: npm config set prefix failed for: $NPM_CONFIG_PREFIX" >&2
      failed=1
    fi

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
    fi

    # Some npm packages ship their bin entrypoints without the executable bit.
    # Ensure anything linked into ~/.local/bin is runnable.
    chmod -R u+rx "$NPM_CONFIG_PREFIX/bin" 2>/dev/null || true
  '';
}
