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
  npmxTools = [
    "@ellery/terminal-mcp@latest"
    "@napisani/scute@latest"
    "skills@latest"
    "openrtk"
    "@agentclientprotocol/claude-agent-acp"
    "@zed-industries/codex-acp"
  ];

  # Declarative skills.sh sources for OpenCode global skills.
  # Additive mode: installs listed skills without removing existing ones.
  opencodeSkillSources = [
    {
      repo = "https://github.com/anthropics/skills";
      skills = [
        "skill-creator"
        "doc-coauthoring"
      ];
    }
    {
      repo = "https://github.com/langchain-ai/deepagents";
      skills = [
        "web-research"
      ];
    }
  ];

  mkSkillInstallCommand =
    source:
    let
      skillArgs = builtins.concatStringsSep " " (
        map (skillName: "--skill ${lib.escapeShellArg skillName}") source.skills
      );
    in
    ''
      npx --yes skills add ${lib.escapeShellArg source.repo} --global --agent opencode --yes --copy ${skillArgs}
    '';

  opencodeSkillInstallCommands = builtins.concatStringsSep "\n" (
    map mkSkillInstallCommand opencodeSkillSources
  );

  npm = "${pkgs-unstable.nodejs}/bin/npm";
  nodeBin = "${pkgs-unstable.nodejs}/bin";
  gitBin = "${pkgs-unstable.git}/bin";
in
{
  home.packages = [
    pkgs-unstable.nodejs
    pkgs-unstable.git
  ];

  home.activation.installNpmxTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export NPM_CONFIG_PREFIX="$HOME/.local"
    mkdir -p "$NPM_CONFIG_PREFIX/bin" "$NPM_CONFIG_PREFIX/lib"
    mkdir -p "$HOME/.config/opencode/skills"
    export DISABLE_TELEMETRY=1

    # Home Manager activation runs with a minimal PATH; ensure npm scripts can
    # find `node`.
    export PATH="${gitBin}:${nodeBin}:$NPM_CONFIG_PREFIX/bin:$PATH"

    failed=0
    for tool in ${builtins.concatStringsSep " " npmxTools}; do
      if ! ${npm} install -g --no-fund --no-audit "$tool"; then
        echo "installNpmxTools: ERROR: npm install -g failed for: $tool" >&2
        failed=$((failed + 1))
      fi
    done
    if [ "$failed" -gt 0 ]; then
      echo "installNpmxTools: $failed tool(s) failed (Neovim agentic ACP CLIs need a successful install). Re-run with network and check the errors above." >&2
    fi

    # Some npm packages ship their bin entrypoints without the executable bit.
    # Ensure anything linked into ~/.local/bin is runnable.
    chmod -R u+rx "$NPM_CONFIG_PREFIX/bin" 2>/dev/null || true

    ${opencodeSkillInstallCommands}
  '';
}
